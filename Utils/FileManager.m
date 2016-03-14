//
//  FileManager.m
//  ImagePickerController
//
//  Created by WangMinglang on 16/3/11.
//  Copyright © 2016年 好价. All rights reserved.
//

#import "FileManager.h"

@implementation FileManager

- (NSURL *)tempFileURL {
    NSString *path = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSInteger i = 0;
    while (path == nil || [fileManager fileExistsAtPath:path]) {
        path = [NSString stringWithFormat:@"%@output%ld.mov", NSTemporaryDirectory(), i];
        i++;
    }
    return [NSURL fileURLWithPath:path];
}

- (void)copyFileToCameraRoll:(NSURL *)fileURL
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if(![library videoAtPathIsCompatibleWithSavedPhotosAlbum:fileURL]){
        NSLog(@"video incompatible with camera roll");
    }
    [library writeVideoAtPathToSavedPhotosAlbum:fileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        
        if(error){
            NSLog(@"Error: Domain = %@, Code = %@", [error domain], [error localizedDescription]);
        } else if(assetURL == nil){
            
            //It's possible for writing to camera roll to fail, without receiving an error message, but assetURL will be nil
            //Happens when disk is (almost) full
            NSLog(@"Error saving to camera roll: no error message, but no url returned");
            
        } else {
            //remove temp file
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:&error];
            if(error){
                NSLog(@"error: %@", [error localizedDescription]);
            }
            
        }
    }];
    
}

@end
