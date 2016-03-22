//
//  SecondViewController.m
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/22.
//  Copyright © 2016年 好价. All rights reserved.
//

#import "SecondViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "FileManager.h"

@interface SecondViewController ()

@property (nonatomic, strong) UIButton *pauseButton;//暂停按钮
@property (nonatomic, strong) UIButton *saveButton;//保存到相册
@property (nonatomic, strong) AVPlayer *player;//播放器


@end

@implementation SecondViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self setupView];
    [self setupPlayer];
}

- (void)setupView {
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, WIDTH, 64)];
    topView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:topView];
    
    UIButton *returnButton = [UIButton buttonWithType:UIButtonTypeCustom];
    returnButton.frame = CGRectMake(0, 0, 100, 50);
    returnButton.center = topView.center;
    [returnButton setTitle:@"return" forState:UIControlStateNormal];
    [returnButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [returnButton addTarget:self action:@selector(returnClick) forControlEvents:UIControlEventTouchUpInside];
    [topView addSubview:returnButton];
    
    UIView *toolView = [[UIView alloc] initWithFrame:CGRectMake(0, 64 + (WIDTH/3*4) + 2, WIDTH, HEIGHT - 64 + (WIDTH/3*4) + 2)];
    toolView.backgroundColor = [UIColor grayColor];
    [self.view addSubview:toolView];
    
    self.pauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.pauseButton.backgroundColor = [UIColor yellowColor];
    self.pauseButton.frame = CGRectMake(0, 0, toolView.frame.size.width/2, toolView.frame.size.height);
    self.pauseButton.tag = 1;
    [self.pauseButton addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.pauseButton];
    
    self.saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.saveButton.backgroundColor = [UIColor redColor];
    self.saveButton.frame = CGRectMake(WIDTH/2, 0, toolView.frame.size.width/2, toolView.frame.size.height);
    [self.saveButton addTarget:self action:@selector(saveButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [toolView addSubview:self.saveButton];

}

- (void)setupPlayer {
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 64, WIDTH, WIDTH/3*4)];
    [self.view addSubview:imageView];
    
    
    
    AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:self.url options:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    playerLayer.frame = CGRectMake(0, 0, WIDTH, WIDTH/3*4);
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [imageView.layer addSublayer:playerLayer];
    [self.player play];

}

- (void)buttonClick:(UIButton *)button {
    if (button.tag) {
        [self.player pause];
    }else {
        [self.player play];
    }
    button.tag = !button.tag;
}

- (void)saveButtonClick {
    FileManager *fm = [[FileManager alloc] init];
    [fm copyFileToCameraRoll:self.url];
}

- (void)returnClick {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
