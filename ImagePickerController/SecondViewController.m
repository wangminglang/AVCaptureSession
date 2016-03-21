//
//  SecondViewController.m
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/18.
//  Copyright © 2016年 好价. All rights reserved.
//

#import "SecondViewController.h"
#import "CameraEngine.h"

@interface SecondViewController ()

@property (nonatomic, strong) UIButton *record;//录制
@property (nonatomic, strong) UIButton *close;//停止
@property (nonatomic, strong) UIButton *pause;//暂停
@property (nonatomic, strong) UIButton *resume;//恢复录制

@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.view.backgroundColor = [UIColor whiteColor];
    [self setupView];
    [self setupConfigure];
}

- (void)setupConfigure {
    [[CameraEngine engine] startup];
    AVCaptureVideoPreviewLayer *previewLayer = [[CameraEngine engine] getPreviewLayer];
    previewLayer.frame = CGRectMake(0, -(HEIGHT - (WIDTH/3*4))/2, WIDTH, HEIGHT);
    [self.view.layer insertSublayer:previewLayer atIndex:0];
}

- (void)setupView {
    UIView *toolView = [[UIView alloc] initWithFrame:CGRectMake(0, WIDTH/3*4 + 5, WIDTH, HEIGHT - WIDTH/3*4 - 5)];
    toolView.backgroundColor = [UIColor blackColor];
    toolView.alpha = 0.5;
    [self.view addSubview:toolView];
    
    self.record = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.record setTitle:@"start" forState:UIControlStateNormal];
    self.record.frame = CGRectMake(WIDTH/2 + (WIDTH/2 - 100)/2, 0, 100, 50);
    [self.record addTarget:self action:@selector(recordClick) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.record];
    
    self.close = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.close setTitle:@"关闭" forState:UIControlStateNormal];
    self.close.frame = CGRectMake((WIDTH/2 - 100)/2, 0, 100, 50);
    [self.close addTarget:self action:@selector(closeClick) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.close];
    
    self.pause = [UIButton buttonWithType:UIButtonTypeCustom];
    self.pause.frame = CGRectMake((WIDTH/2 - 100)/2, 100, 100, 50);
    [self.pause setTitle:@"暂停" forState:UIControlStateNormal];
    [self.pause addTarget:self action:@selector(pauseClick) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.pause];
    
    self.resume = [UIButton buttonWithType:UIButtonTypeCustom];
    self.resume.frame = CGRectMake(WIDTH/2 + (WIDTH/2 - 100)/2, 100, 100, 50);
    [self.resume setTitle:@"恢复录制" forState:UIControlStateNormal];
    [self.resume addTarget:self action:@selector(resumeClick) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.resume];
        
}

#pragma mark - Click methods
- (void)recordClick {
    [[CameraEngine engine] startCapture];
}

- (void)closeClick {
    [[CameraEngine engine] stopCapture];
}

- (void)pauseClick {
    [[CameraEngine engine] pauseCapture];
}

- (void)resumeClick {
    [[CameraEngine engine] resumeCapture];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
