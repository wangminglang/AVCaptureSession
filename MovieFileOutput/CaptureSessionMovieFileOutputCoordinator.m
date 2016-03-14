//
//  CaptureSessionMovieFileOutputCoordinator.m
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/11.
//  Copyright © 2016年 好价. All rights reserved.
//

#import "CaptureSessionMovieFileOutputCoordinator.h"
#import "FileManager.h"



@interface CaptureSessionMovieFileOutputCoordinator () <AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;

@end

@implementation CaptureSessionMovieFileOutputCoordinator

- (instancetype)init
{
    self = [super init];
    if(self){
        [self addMovieFileOutputToCaptureSession:self.captureSession];
    }
    return self;
}

#pragma mark - Private methods

- (BOOL)addMovieFileOutputToCaptureSession:(AVCaptureSession *)captureSession
{
    self.movieFileOutput = [AVCaptureMovieFileOutput new];
    return  [self addOutput:_movieFileOutput toCaptureSession:captureSession];
}

#pragma mark - Recording

- (void)startRecording
{
    FileManager *fm = [FileManager new];
    NSURL *tempURL = [fm tempFileURL];
    [_movieFileOutput startRecordingToOutputFileURL:tempURL recordingDelegate:self];
}

- (void)stopRecording
{
    [_movieFileOutput stopRecording];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate methods
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
      fromConnections:(NSArray *)connections
{
    //Recording started
    [self.delegate coordinatorDidBeginRecording:self];
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    //Recording finished - do something with the file at outputFileURL
    [self.delegate coordinator:self didFinishRecordingToOutputFileURL:outputFileURL error:error];
    
}

@end
