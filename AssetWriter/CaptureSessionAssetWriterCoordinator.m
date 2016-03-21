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

@property (nonatomic, assign) BOOL isCapturing;//正在录制
@property (nonatomic, assign) BOOL isPaused;//暂停


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
    
}

- (void)resumeRecording {
    
}

#pragma mark - SampleBufferDelegate methods
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
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
