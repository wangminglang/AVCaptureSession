//
//  CameraEngine.m
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/18.
//  Copyright © 2016年 好价. All rights reserved.
//

#import "CameraEngine.h"
#import "VideoEncoder.h"
#import "AssetsLibrary/ALAssetsLibrary.h"

static CameraEngine *engine = nil;

@interface CameraEngine () <AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureAudioDataOutputSampleBufferDelegate>
{
    int _cx;
    int _cy;
    int _channels;
    Float64 _samplerate;
}

@property (nonatomic, assign) BOOL isCapturing;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) BOOL isDiscont;
@property (nonatomic, assign) CMTime timeOffset;
@property (nonatomic, assign) CMTime lastVideo;
@property (nonatomic, assign) CMTime lastAudio;
@property (nonatomic, assign) int currentFile;

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) dispatch_queue_t captureQueue;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic, strong) AVCaptureConnection *audioConnection;

@property (nonatomic, strong) VideoEncoder *videoEncoder;


@end

@implementation CameraEngine

+ (CameraEngine *)engine {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        engine = [[CameraEngine alloc] init];
    });
    return engine;
}

- (void)startCapture {
    @synchronized(self) {
        if (!self.isCapturing) {
            self.isPaused = NO;
            self.isCapturing = YES;
            self.isDiscont = NO;
            self.timeOffset = CMTimeMake(0, 0);
            self.videoEncoder = nil;
        }
    }
}

- (void)stopCapture {
    @synchronized(self) {
        if (self.isCapturing) {
            self.isCapturing = NO;
            NSString *fileName = [NSString stringWithFormat:@"capture%d.mp4", self.currentFile];
            NSString *path = [NSTemporaryDirectory() stringByAppendingString:fileName];
            NSURL *url = [NSURL fileURLWithPath:path];
            self.currentFile++;
            dispatch_async(_captureQueue, ^{
                [self.videoEncoder finishWithCompletionHandler:^{
                    self.isCapturing = NO;
                    self.videoEncoder = nil;
                    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                    [library writeVideoAtPathToSavedPhotosAlbum:url completionBlock:^(NSURL *assetURL, NSError *error) {
                        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                    }];
                }];
            });
        }
    }
}

- (void)pauseCapture {
    @synchronized(self) {
        if (self.isCapturing) {
            self.isPaused = YES;
            self.isDiscont = YES;
        }
    }
}

- (void)resumeCapture {
    @synchronized(self) {
        if (self.isPaused) {
            self.isPaused = NO;
        }
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //分段录制也就是可以暂停之后恢复录制，并且录制结束之后是在同一个文件中。不管video还是audio都是有时间戳的frame，因为有时间戳播放器才能有序的进行播放。因此在分段录制中，只要在暂停的时候记录一下当前的一个时间戳，然后在恢复之后计算一下这之间的时间差，然后在将这个frame写入之前修改一下这个frame的时间戳就行了
    BOOL bVideo = YES;
    @synchronized(self) {
        if (!self.isCapturing || self.isPaused) {
            return;
        }
        if (connection != self.videoConnection) {
            bVideo = NO;
        }
        if ((self.videoEncoder == nil) && !bVideo) {
            CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
            [self setAudioFormat:fmt];
            NSString* filename = [NSString stringWithFormat:@"capture%d.mp4", _currentFile];
            NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
            self.videoEncoder = [VideoEncoder encoderForPath:path Height:_cy width:_cx channels:_channels samples:_samplerate];
        }
        if (_isDiscont) {
            if (bVideo) {
                return;
            }
            _isDiscont = NO;
            CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            CMTime last = bVideo ? _lastVideo : _lastAudio;
            if (last.flags & kCMTimeFlags_Valid) {
                if (_timeOffset.flags & kCMTimeFlags_Valid) {
                    pts = CMTimeSubtract(pts, _timeOffset);
                }
                CMTime offset = CMTimeSubtract(pts, last);
                // this stops us having to set a scale for _timeOffset before we see the first video time
                if (_timeOffset.value == 0) {
                    _timeOffset = offset;
                }else {
                    _timeOffset = CMTimeAdd(_timeOffset, offset);
                }
            }
            _lastVideo.flags = 0;
            _lastAudio.flags = 0;
        }
        // retain so that we can release either this or modified one
        CFRetain(sampleBuffer);
        if (_timeOffset.value > 0) {
            CFRelease(sampleBuffer);
            sampleBuffer = [self adjustTime:sampleBuffer by:_timeOffset];
        }
        // record most recent time so we know the length of the pause
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime dur = CMSampleBufferGetDuration(sampleBuffer);
        if (dur.value > 0) {
            pts = CMTimeAdd(pts, dur);
        }
        if (bVideo) {
            _lastVideo = pts;
        }else {
            _lastAudio = pts;
        }
    }
    // pass frame to encoder
    [_videoEncoder encodeFrame:sampleBuffer isVideo:bVideo];
    CFRelease(sampleBuffer);
}

- (void) setAudioFormat:(CMFormatDescriptionRef) fmt
{
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt);
    _samplerate = asbd->mSampleRate;
    _channels = asbd->mChannelsPerFrame;
    
}

- (CMSampleBufferRef)adjustTime:(CMSampleBufferRef) sample by:(CMTime) offset
{
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++)
    {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

- (void)startup {
    if (_captureSession == nil) {
        self.isCapturing = NO;
        self.isPaused = NO;
        self.isDiscont = NO;
        self.currentFile = 0;
        
        _captureSession = [[AVCaptureSession alloc] init];
        _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
        
        AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        if ([_captureSession canAddInput:videoDeviceInput]) {
            [_captureSession addInput:videoDeviceInput];
        }
        
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
        if ([_captureSession canAddInput:audioDeviceInput]) {
            [_captureSession addInput:audioDeviceInput];
        }
        
        _captureQueue = dispatch_queue_create("uk.co.gdcl.cameraengine.capture", DISPATCH_QUEUE_SERIAL);
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        [videoDataOutput setSampleBufferDelegate:self queue:_captureQueue];
        NSDictionary* setcapSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                                        nil];
        videoDataOutput.videoSettings = setcapSettings;
        [_captureSession addOutput:videoDataOutput];
        _videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
        NSDictionary* actual = videoDataOutput.videoSettings;
        _cy = [[actual objectForKey:@"Height"] integerValue];
        _cx = [[actual objectForKey:@"Width"] integerValue];
        
        AVCaptureAudioDataOutput *audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
        [audioDataOutput setSampleBufferDelegate:self queue:_captureQueue];
        [_captureSession addOutput:audioDataOutput];
        _audioConnection = [audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
        [_captureSession startRunning];
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    }
}

- (AVCaptureVideoPreviewLayer *)getPreviewLayer {
    return _previewLayer;
}

@end
