//
//  CameraEngine.h
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/18.
//  Copyright © 2016年 好价. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraEngine : NSObject

+ (CameraEngine *)engine;

- (void)startup;
- (void)startCapture;
- (void)pauseCapture;
- (void)stopCapture;
- (void)resumeCapture;


- (AVCaptureVideoPreviewLayer *)getPreviewLayer;

@end
