//
//  CaptureSessionAssetWriterCoordinator.m
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/11.
//  Copyright © 2016年 好价. All rights reserved.
//

#import "CaptureSessionAssetWriterCoordinator.h"
#import "FileManager.h"
#import "AssetWriterCoordinator.h"

typedef NS_ENUM( NSInteger, RecordingStatus )
{
    RecordingStatusIdle = 0,
    RecordingStatusStartingRecording,
    RecordingStatusRecording,
    RecordingStatusStoppingRecording,
}; // internal state machine


@interface CaptureSessionAssetWriterCoordinator () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate,
    AssetWriterCoordinatorDelegate>

@property (nonatomic, strong) dispatch_queue_t videoDataOutputQuene;
@property (nonatomic, strong) dispatch_queue_t audioDataOutputQueue;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic, strong) AVCaptureConnection *audioConnection;
@property (nonatomic, strong) NSDictionary *videoCompressionSettings;
@property (nonatomic, strong) NSDictionary *audioCompressionSettings;

@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, assign) RecordingStatus recordingStatus;

@property (nonatomic, strong) NSURL *recordingURL;
@property(nonatomic, retain) __attribute__((NSObject)) CMFormatDescriptionRef outputVideoFormatDescription;
@property(nonatomic, retain) __attribute__((NSObject)) CMFormatDescriptionRef outputAudioFormatDescription;
@property(nonatomic, retain) AssetWriterCoordinator *assetWriterCoordinator;

@property (nonatomic, assign) BOOL isDiscont;
@property (nonatomic, assign) BOOL isPaused;//暂停

@property (nonatomic, assign) CMTime timeOffset;
@property (nonatomic, assign) CMTime lastVideo;
@property (nonatomic, assign) CMTime lastAudio;



@end

@implementation CaptureSessionAssetWriterCoordinator

- (instancetype)init {
    self = [super init];
    if (self) {
        _videoDataOutputQuene = dispatch_queue_create("com.example.capturesession.videodata", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_videoDataOutputQuene, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        _audioDataOutputQueue = dispatch_queue_create("com.example.capturesession.audiodata", DISPATCH_QUEUE_SERIAL);
        [self addDataOutputsToCaptureSession:self.captureSession];
        
    }
    return self;
}

- (void)startRecording {
    @synchronized(self) {
        if (_recordingStatus != RecordingStatusIdle) {
            //抛出异常
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Already recording" userInfo:nil];
            return;
        }
        [self transitionToRecordingStatus:RecordingStatusStartingRecording error:nil];
    }
    
    FileManager *manager = [[FileManager alloc] init];
    _recordingURL = [manager tempFileURL];
    self.assetWriterCoordinator = [[AssetWriterCoordinator alloc] initWithURL:_recordingURL];
    if (_outputAudioFormatDescription != nil) {
        [_assetWriterCoordinator addAudioTrackWithSourceFormatDescription:self.outputAudioFormatDescription settings:_audioCompressionSettings];
    }
    [_assetWriterCoordinator addVideoTrackWithSourceFormatDescription:self.outputVideoFormatDescription settings:_videoCompressionSettings];
    dispatch_queue_t callbackQueue = dispatch_queue_create( "com.example.capturesession.writercallback", DISPATCH_QUEUE_SERIAL ); // guarantee ordering of callbacks with a serial queue
    [_assetWriterCoordinator setDelegate:self callbackQueue:callbackQueue];
    [_assetWriterCoordinator prepareToRecord];
}

- (void)stopRecording {
    @synchronized(self) {
        if (_recordingStatus != RecordingStatusRecording) {
            return;
        }
        [self transitionToRecordingStatus:RecordingStatusStoppingRecording error:nil];
    }
    [self.assetWriterCoordinator finishRecording];
}

- (void)pauseRecording {
    self.isDiscont = YES;
    self.isPaused = YES;
}

- (void)resumeRecording {
    self.isPaused = NO;
}

#pragma mark - SampleBufferDelegate methods
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    BOOL bVideo = YES;
    if (self.isPaused) {
        return;
    }
    if (connection != self.videoConnection) {
        bVideo = NO;
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
    if (connection == _videoConnection) {
        if (self.outputVideoFormatDescription == nil) {
            [self setupPipelineWithInputFormatDescription:formatDescription];
        }else {
            self.outputVideoFormatDescription = formatDescription;
            @synchronized(self) {
                if (_recordingStatus == RecordingStatusRecording) {
                    [self.assetWriterCoordinator appendVideoSampleBuffer:sampleBuffer];
                }
            }
        }
    }else if (connection == _audioConnection) {
        self.outputAudioFormatDescription = formatDescription;
        @synchronized(self) {
            if (_recordingStatus == RecordingStatusRecording) {
                [_assetWriterCoordinator appendAudioSampleBuffer:sampleBuffer];
            }
        }
    }
    CFRelease(sampleBuffer);
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

- (void)setupPipelineWithInputFormatDescription:(CMFormatDescriptionRef)inputFormatDescription {
    self.outputVideoFormatDescription = inputFormatDescription;
}

#pragma mark - AssetWriterCoordinatorDelegate
- (void)writerCoordinatorDidFinishPreparing:(AssetWriterCoordinator *)coordinator {
    @synchronized(self) {
        if (_recordingStatus != RecordingStatusStartingRecording) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Expected to be in StartingRecording state" userInfo:nil];
            return;
        }
        [self transitionToRecordingStatus:RecordingStatusRecording error:nil];
    }
}

- (void)writerCoordinator:(AssetWriterCoordinator *)recorder didFailWithError:(NSError *)error
{
    @synchronized( self ) {
        self.assetWriterCoordinator = nil;
        [self transitionToRecordingStatus:RecordingStatusIdle error:error];
    }
}

- (void)writerCoordinatorDidFinishRecording:(AssetWriterCoordinator *)coordinator {
    @synchronized( self )
    {
        if ( _recordingStatus != RecordingStatusStoppingRecording ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Expected to be in StoppingRecording state" userInfo:nil];
            return;
        }
        // No state transition, we are still in the process of stopping.
        // We will be stopped once we save to the assets library.
    }
    
    self.assetWriterCoordinator = nil;
    
    @synchronized( self ) {
        [self transitionToRecordingStatus:RecordingStatusIdle error:nil];
    }
}


#pragma mark - Recording status Machine
- (void)transitionToRecordingStatus:(RecordingStatus)newStatus error:(NSError *)error {
    RecordingStatus oldStatus = _recordingStatus;
    _recordingStatus = newStatus;
    
    if (oldStatus != newStatus) {
        if (error && (newStatus == RecordingStatusRecording)) {
            dispatch_async(self.delegateCallbackQueue, ^{
                @autoreleasepool {
                    [self.delegate coordinator:self didFinishRecordingToOutputFileURL:_recordingURL error:nil];
                }
            });
        }else {
            error = nil;
            if (oldStatus == RecordingStatusStartingRecording && newStatus == RecordingStatusRecording) {
                dispatch_async(self.delegateCallbackQueue, ^{
                    [self.delegate coordinatorDidBeginRecording:self];
                });
            }else if (oldStatus == RecordingStatusStoppingRecording && newStatus == RecordingStatusIdle) {
                dispatch_async(self.delegateCallbackQueue, ^{
                    [self.delegate coordinator:self didFinishRecordingToOutputFileURL:_recordingURL error:nil];
                });
            }
        }
    }
}

#pragma mark - Private methods
- (void)addDataOutputsToCaptureSession:(AVCaptureSession *)captureSession {
    self.videoDataOutput = [AVCaptureVideoDataOutput new];
    _videoDataOutput.videoSettings = nil;
    _videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    [_videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQuene];
    self.audioDataOutput = [AVCaptureAudioDataOutput new];
    [_audioDataOutput setSampleBufferDelegate:self queue:self.audioDataOutputQueue];
    [self addOutput:_videoDataOutput toCaptureSession:self.captureSession];
    _videoConnection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [self addOutput:_audioDataOutput toCaptureSession:self.captureSession];
    _audioConnection = [_audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    [self setCompressionSettings];
}

- (void)setCompressionSettings {
    //定义输出设置，比如，增加视频比特率来提高视频质量等
    _videoCompressionSettings = [_videoDataOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeQuickTimeMovie];
    _audioCompressionSettings = [_audioDataOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeQuickTimeMovie];
}



@end
