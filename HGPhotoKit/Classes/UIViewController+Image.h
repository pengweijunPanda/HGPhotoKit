//
//  UIViewController+Image.h
//  PPImageKit
//
//  Created by pengweijun on 2019/6/14.
//  Copyright © 2019年 彭伟军. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol UIViewControllerCameraDelegate <NSObject>

@optional

- (void)pp_imagePickerControllerDidCancel:(UIViewController *)vc;

- (void)pp_imagePickerController:(UIViewController *)vc cameraDidFinishPickingMediaWithImage:(UIImage *)image;

- (void)pp_imagePickerController:(UIViewController *)vc albumPickImageData:(UIImage *)image isGif:(BOOL)isGif localPath:(NSString *)localPath;

- (void)pp_imagePickerController:(UIViewController *)vc cameraDidFinishPickingMediaWithImage:(UIImage *)image imageSize:(long long)imageSize;

- (void)pp_imagePickerController:(UIViewController *)vc cameraDidFinishPickingMediaWithAssetUrl:(NSURL *)asseturl;

@end


@interface UIViewController (Image)<UIImagePickerControllerDelegate,UINavigationControllerDelegate>

@end

NS_ASSUME_NONNULL_END
