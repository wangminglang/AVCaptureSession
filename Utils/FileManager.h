//
//  FileManager.h
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/11.
//  Copyright © 2016年 好价. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileManager : NSObject

- (NSURL *)tempFileURL;

- (void)copyFileToCameraRoll:(NSURL *)fileURL;

@end
