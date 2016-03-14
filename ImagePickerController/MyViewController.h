//
//  MyViewController.h
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/10.
//  Copyright © 2016年 好价. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PipelineMode)
{
    PipelineModeMovieFileOutput = 0,
    PipelineModeAssetWriter,
};

@interface MyViewController : UIViewController

- (void)setupCaptureSessionWithModel:(PipelineMode)mode;

@end
