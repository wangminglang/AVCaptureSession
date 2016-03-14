//
//  ViewController.m
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/10.
//  Copyright © 2016年 好价. All rights reserved.
//

#import "ViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import "MyViewController.h"


@interface ViewController () <UITableViewDataSource, UITableViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIImagePickerController *imagePickerController;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self setupUI];
}

- (void)setupUI {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, WIDTH, HEIGHT) style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    cell.textLabel.text = [NSString stringWithFormat:@"index -- %ld", indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:
        {
            [self setupImagePickerController];
            self.imagePickerController.delegate = self;
            [self presentViewController:self.imagePickerController animated:YES completion:nil];
        }
            break;
        case 1:
        {
            MyViewController *VC = [[MyViewController alloc] init];
            [VC setupCaptureSessionWithModel:PipelineModeMovieFileOutput];
            [self presentViewController:VC animated:YES completion:nil];
        }
            break;
        case 2:
        {
            MyViewController *VC = [[MyViewController alloc] init];
            [VC setupCaptureSessionWithModel:PipelineModeAssetWriter];
            [self presentViewController:VC animated:YES completion:nil];
        }
            break;
            
        default:
            break;
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (void)setupImagePickerController {
    self.imagePickerController = [[UIImagePickerController alloc] init];
    self.imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.imagePickerController.mediaTypes = @[(NSString *)kUTTypeMovie];
    self.imagePickerController.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    self.imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
