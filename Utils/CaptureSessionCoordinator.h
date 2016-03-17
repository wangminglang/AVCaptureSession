//
//  CaptureSessionCoordinator.h
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/11.
//  Copyright © 2016年 好价. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@protocol CaptureSessionCoordinatorDelegate;

@interface CaptureSessionCoordinator : NSObject

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice *cameraDevice;
@property (nonatomic, strong) dispatch_queue_t delegateCallbackQueue;
@property (nonatomic, weak) id<CaptureSessionCoordinatorDelegate> delegate;

- (void)setDelegate:(id<CaptureSessionCoordinatorDelegate>)delegate callbackQueue:(dispatch_queue_t)delegateCallbackQueue;

- (BOOL)addInput:(AVCaptureDeviceInput *)input toCaptureSession:(AVCaptureSession *)captureSession;
- (BOOL)addOutput:(AVCaptureOutput *)output toCaptureSession:(AVCaptureSession *)captureSession;

- (void)startRunning;
- (void)stopRunning;

- (void)startRecording;
- (void)stopRecording;

- (void)pauseRecording;
- (void)resumeRecording;

- (void)focusAtPoint:(CGPoint)point completionHandler:(void (^)())handler;//对焦

- (void)changeClick;//切摄像头
- (void)flashClick:(UIButton *)sender;//闪光灯开关

- (AVCaptureVideoPreviewLayer *)previewLayer;

@end

@protocol CaptureSessionCoordinatorDelegate <NSObject>

@required

- (void)coordinatorDidBeginRecording:(CaptureSessionCoordinator *)coordinator;
- (void)coordinator:(CaptureSessionCoordinator *)coordinator didFinishRecordingToOutputFileURL:(NSURL *)outputFileURL error:(NSError *)error;

@end
