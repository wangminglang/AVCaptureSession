//
//  MyViewController.m
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/10.
//  Copyright © 2016年 好价. All rights reserved.
//

#import "MyViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "FileManager.h"
#import "CaptureSessionAssetWriterCoordinator.h"
#import "CaptureSessionMovieFileOutputCoordinator.h"
#import "SecondViewController.h"

@interface MyViewController () <CaptureSessionCoordinatorDelegate>

@property (nonatomic, strong) CaptureSessionCoordinator *captureSessionCoordinator;

@property (nonatomic, assign) BOOL isRecording;//正在录制
@property (nonatomic, assign) BOOL dismissing;
@property (nonatomic, strong) UIButton *record;
@property (nonatomic, strong) UIButton *close;
@property (nonatomic, strong) UIButton *change;//切摄像头
@property (nonatomic, strong) UIButton *flash;//闪光灯
@property (nonatomic, strong) UIButton *pause;//暂停、恢复录制
@property (nonatomic, strong) UIButton *stop;//页面跳转
@property (nonatomic, strong) UIView *focalReticule;//对焦十字
@property (nonatomic, strong) NSURL *url;

@end

@implementation MyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.view.backgroundColor = [UIColor whiteColor];
    [self setupView];
}

- (void)setupView {
    UIView *toolView = [[UIView alloc] initWithFrame:CGRectMake(0, WIDTH/3*4 + 5, WIDTH, HEIGHT - WIDTH/3*4 - 5)];
    toolView.backgroundColor = [UIColor blackColor];
    toolView.alpha = 0.5;
    [self.view addSubview:toolView];
    
    self.record = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.record setTitle:@"start" forState:UIControlStateNormal];
    self.record.frame = CGRectMake(WIDTH/2 + (WIDTH/2 - 100)/2, 0, 100, 50);
    [self.record addTarget:self action:@selector(recordClick:) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.record];
    
    self.close = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.close setTitle:@"关闭" forState:UIControlStateNormal];
    self.close.frame = CGRectMake((WIDTH/2 - 100)/2, 0, 100, 50);
    [self.close addTarget:self action:@selector(closeClick) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.close];
    
    self.change = [UIButton buttonWithType:UIButtonTypeCustom];
    self.change.frame = CGRectMake(WIDTH/2 + (WIDTH/2 - 100)/2, 50, 100, 50);
    [self.change setTitle:@"切摄像头" forState:UIControlStateNormal];
    self.change.tag = 1;
    [self.change addTarget:self action:@selector(changeClick:) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.change];
    
    self.flash = [UIButton buttonWithType:UIButtonTypeCustom];
    self.flash.frame = CGRectMake((WIDTH/2 - 100)/2, 50, 100, 50);
    [self.flash setTitle:@"闪光灯" forState:UIControlStateNormal];
    [self.flash addTarget:self action:@selector(flashClick:) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.flash];
    
    self.pause = [UIButton buttonWithType:UIButtonTypeCustom];
    self.pause.frame = CGRectMake((WIDTH/2 - 100)/2, 100, 100, 50);
    [self.pause setTitle:@"录制状态" forState:UIControlStateNormal];
    self.pause.tag = 1;
    [self.pause addTarget:self action:@selector(pauseClick:) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.pause];

    self.stop = [UIButton buttonWithType:UIButtonTypeCustom];
    self.stop.frame = CGRectMake(WIDTH/2 + (WIDTH/2 - 100)/2, 100, 100, 50);
    [self.stop setTitle:@"stop" forState:UIControlStateNormal];
    [self.stop addTarget:self action:@selector(stopClick) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.stop];
    
    //对焦十字
    _focalReticule=[[UIView alloc]initWithFrame:CGRectMake(0, 0, 60, 60)];
    _focalReticule.backgroundColor=[UIColor clearColor];
    //十字
    UIView *line1=[[UIView alloc]initWithFrame:CGRectMake(0, 29.5, 60, 1)];
    line1.backgroundColor=[UIColor redColor];
    [_focalReticule addSubview:line1];
    
    UIView *line2=[[UIView alloc]initWithFrame:CGRectMake(29.5, 0, 1, 60)];
    line2.backgroundColor=[UIColor redColor];
    [_focalReticule addSubview:line2];
    [self.view addSubview:_focalReticule];
    //默认隐藏
    _focalReticule.hidden=YES;
    
    //点击屏幕对焦的手势
    UITapGestureRecognizer *forcesTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(focus:)];
    [self.view addGestureRecognizer:forcesTap];
    
}

- (void)setupCaptureSessionWithModel:(PipelineMode)mode {
    switch (mode) {
        case PipelineModeMovieFileOutput:
            self.captureSessionCoordinator = [[CaptureSessionMovieFileOutputCoordinator alloc] init];
            break;
        case PipelineModeAssetWriter:
            self.captureSessionCoordinator = [[CaptureSessionAssetWriterCoordinator alloc] init];
            break;
            
        default:
            break;
    }
    [self.captureSessionCoordinator setDelegate:self callbackQueue:dispatch_get_main_queue()];
    [self configureInterface];
}

- (void)configureInterface {
    AVCaptureVideoPreviewLayer *previewLayer = [self.captureSessionCoordinator previewLayer];
    previewLayer.frame = CGRectMake(0, 0, WIDTH, WIDTH/3*4);
    [self.view.layer insertSublayer:previewLayer atIndex:0];
    [self.captureSessionCoordinator startRunning];
}

- (void)stopRunningAndDismiss {
    [self.captureSessionCoordinator stopRunning];
    [self dismissViewControllerAnimated:YES completion:nil];
    self.dismissing = NO;
}

#pragma mark - ControlMethods
//开始、停止
- (void)recordClick:(UIButton *)record {
    if (self.isRecording) {
        [self.captureSessionCoordinator stopRecording];
    }else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        record.enabled = NO;
        [record setTitle:@"stop" forState:UIControlStateNormal];
        [self.captureSessionCoordinator startRecording];
        self.isRecording = YES;
    }
}

//关闭
- (void)closeClick {
    if (self.isRecording) {
        self.dismissing = YES;
        [self.captureSessionCoordinator stopRecording];
    }else {
        [self stopRunningAndDismiss];
    }
}

//闪光灯
- (void)flashClick:(UIButton *)sender {
    sender.selected = !sender.selected;
    [self.captureSessionCoordinator flashClick:sender];
}

//对焦
- (void)focus:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        CGPoint point = [gesture locationInView:self.view];
        __block typeof(self) weakSelf = self;
        [self.captureSessionCoordinator focusAtPoint:point completionHandler:^{
            weakSelf.focalReticule.center=point;
            weakSelf.focalReticule.alpha=0.0;
            weakSelf.focalReticule.hidden=NO;
            [UIView animateWithDuration:0.3 animations:^{
                weakSelf.focalReticule.alpha=1.0;
            }completion:^(BOOL finished) {
                [UIView animateWithDuration:0.3 animations:^{
                    weakSelf.focalReticule.alpha=0.0;
                }];
            }];
        }];
    }
}

//切摄像头
- (void)changeClick:(UIButton *)button {
    [self.captureSessionCoordinator changeClick];
}

//暂停、恢复录制
- (void)pauseClick:(UIButton *)sender {
    if (sender.tag) {
        [self.captureSessionCoordinator pauseRecording];
        [self.pause setTitle:@"暂停状态" forState:UIControlStateNormal];
    }else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self.captureSessionCoordinator resumeRecording];
        [self.pause setTitle:@"录制状态" forState:UIControlStateNormal];
    }
    sender.tag = !sender.tag;
}

//next
- (void)stopClick {
    if (self.isRecording) {
        [self.captureSessionCoordinator stopRecording];
    }
    SecondViewController *VC = [[SecondViewController alloc] init];
    VC.url = self.url;
    [self presentViewController:VC animated:YES completion:nil];
}

#pragma mark - CaptureSessionCoordinatorDelegate
- (void)coordinatorDidBeginRecording:(CaptureSessionCoordinator *)coordinator {
    self.record.enabled = YES;
}

- (void)coordinator:(CaptureSessionCoordinator *)coordinator didFinishRecordingToOutputFileURL:(NSURL *)outputFileURL error:(NSError *)error {
    self.url = outputFileURL;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    self.isRecording = NO;
    [self.record setTitle:@"start" forState:UIControlStateNormal];
//    FileManager *fm = [[FileManager alloc] init];
//    [fm copyFileToCameraRoll:outputFileURL];
    
    if (self.dismissing) {
        [self stopRunningAndDismiss];
    }
}

@end
