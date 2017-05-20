//
//  ImageDelegate.m
//  surespot
//
//  Created by Adam on 12/1/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "ImageDelegate.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "UIImage+Scale.h"
#import "EncryptionController.h"
#import "NetworkManager.h"
#import "SurespotConstants.h"
#import "IdentityController.h"
#import "ALAssetsLibrary+CustomPhotoAlbum.h"
#import "SwipeViewController.h"
#import "SurespotMessage.h"
#import "FileController.h"
#import "ChatManager.h"
#import "NSData+Base64.h"
#import "NSData+SRB64Additions.h"
#import "SDWebImageManager.h"
#import "CocoaLumberjack.h"
#import "UIUtils.h"
#import "MWPhotoBrowser.h"
#import "MWPhoto.h"
#import "NSBundle+FallbackLanguage.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface ImageDelegate()
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSString * theirUsername;
@property (nonatomic, strong) NSString * ourVersion;
@property (nonatomic, weak) ALAssetsLibrary * assetsLibrary;
@property (nonatomic, weak) UIViewController* controller;
@property (nonatomic, strong) NSURL * selectedImageUrl;
@property (nonatomic, strong) UIImage * selectedImage;
@end


@implementation ImageDelegate


- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion
          theirUsername:(NSString *) theirUsername
           assetLibrary: (ALAssetsLibrary *) library
{
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    _username = username;
    _ourVersion = ourVersion;
    _theirUsername = theirUsername;
    _assetsLibrary = library;
    return self;
}



// For responding to the user tapping Cancel.
- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
    [_controller dismissViewControllerAnimated: YES completion:nil];
}

// For responding to the user accepting a newly-captured picture or movie
- (void) imagePickerController: (UIImagePickerController *) picker
 didFinishPickingMediaWithInfo: (NSDictionary *) info {
    
    [[picker presentingViewController] dismissViewControllerAnimated: YES completion:nil];
    
    
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    UIImage *originalImage, *editedImage, *imageToSave;
    NSURL *imageUrl;
    // Handle a still image capture
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0)
        == kCFCompareEqualTo) {
        
        editedImage = (UIImage *) [info objectForKey:
                                   UIImagePickerControllerEditedImage];
        originalImage = (UIImage *) [info objectForKey:
                                     UIImagePickerControllerOriginalImage];
        
        imageUrl = (NSURL *) [info objectForKey:UIImagePickerControllerReferenceURL];
        
        
        if (editedImage) {
            imageToSave = editedImage;
        } else {
            imageToSave = originalImage;
        }
        
        [self startProgress];
        
        
        switch (_mode) {
            case kSurespotImageDelegateModeCapture:
            {
                [_assetsLibrary saveImage:imageToSave toAlbum:@"surespot" withCompletionBlock:^(NSError *error, NSURL * url) {
                    _assetsLibrary = nil;
                    [self uploadImage:url];
                }];
                break;
            }
            case kSurespotImageDelegateModeSelect:
            {
                _selectedImage = imageToSave;
                _selectedImageUrl = imageUrl;
                _assetsLibrary = nil;
                
                MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
                
                browser.displayActionButton = YES; // Show action button to allow sharing, copying, etc (defaults to YES)
                browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
                browser.zoomPhotosToFill = YES; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
                browser.alwaysShowControls = YES;
                
                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                    [_popover dismissPopoverAnimated:NO];
                    _popover = nil;
                }
                
                browser.navigationItem.title = NSLocalizedString(@"pan_and_zoom", nil);
                
                [self.controller.navigationController pushViewController:browser animated:NO];
                [browser setNavBarAppearance:NO tintColor: [UIUtils surespotBlue]];
            }
                break;
            case kSurespotImageDelegateModeFriendImage:
                _assetsLibrary = nil;
                [self uploadFriendImage:imageToSave];
                break;
            case kSurespotImageDelegateModeBackgroundImage:
                [self setBackgroundImage:imageToSave];
                break;
                
        }
    }
}

-(void) setBackgroundImage: (UIImage *) image {
    //scale image
    CGSize size = [UIScreen mainScreen].bounds.size;
    CGFloat maxf = MAX(size.width, size.height);
    UIImage * scaledImage = [image imageScaledToMinDimension:maxf];
    
    //save to file
    NSString * filepath =[FileController getBackgroundImageFilename: _username];
    [UIImagePNGRepresentation(scaledImage) writeToFile: filepath atomically:YES];
    NSURL * url = [NSURL fileURLWithPath:filepath];
    
    //update settings string
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSString * removeString = NSLocalizedString(@"pref_title_background_image_remove", nil);
    [defaults setObject:removeString forKey: [_username stringByAppendingString: @"_user_assign_background_image_key"]];
    [defaults setURL:url forKey:[NSString stringWithFormat:@"%@%@", _username, @"_background_image_url"]];
    
    
    //update UI
    [[NSNotificationCenter defaultCenter] postNotificationName:@"backgroundImageChanged" object:_controller];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [_popover dismissPopoverAnimated:YES];
        _popover = nil;
    }
}


-(void) uploadImage: (NSURL *) imageUrl {
    if (!imageUrl) {
        [self stopProgress];
        [UIUtils showToastKey:@"could_not_upload_image" duration:2];
        return;
    }
    
    [[[ChatManager sharedInstance] getChatController:_username] sendImageMessage:[imageUrl absoluteString] to:_theirUsername];
}


-(void) uploadFriendImage: (UIImage *) image {
    if (!image) {
        [self stopProgress];
        [UIUtils showToastKey:@"could_not_upload_friend_image" duration:2];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //compress encrypt and upload the image
        UIImage * scaledImage = [image imageScaledToMaxWidth:100 maxHeight:100];
        NSData * imageData = UIImageJPEGRepresentation(scaledImage, 0.5);
        NSData * iv = [EncryptionController getIv];
        NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
        
        //encrypt
        [EncryptionController symmetricEncryptData:imageData
                                       ourUsername:_username
                                        ourVersion:_ourVersion
                                     theirUsername:_username
                                      theirVersion:_ourVersion
                                                iv:b64iv
                                          callback:^(NSData * encryptedImageData) {
                                              if (encryptedImageData) {
                                                  
                                                  NSString * key = [@"friendImageKey_" stringByAppendingString: b64iv];
                                                  
                                                  
                                                  DDLogInfo(@"adding local friend image to cache %@", key);
                                                  [[[SDWebImageManager sharedManager] imageCache] storeImage:scaledImage imageData:encryptedImageData mimeType: MIME_TYPE_IMAGE forKey:key toDisk:YES];
                                                  
                                                  //upload friend image to server
                                                  DDLogInfo(@"uploading friend image %@ to server", key);
                                                  [[[NetworkManager sharedInstance] getNetworkController:_username] postFriendStreamData:encryptedImageData
                                                                                                                              ourVersion:_ourVersion
                                                                                                                           theirUsername:_theirUsername
                                                                                                                                      iv:[iv SR_stringByBase64Encoding]
                                                                                                                            successBlock:^(id responseObject) {
                                                                                                                                [self stopProgress];
                                                                                                                                if (responseObject) {
                                                                                                                                    NSString * url = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                                                                                                                                    DDLogInfo(@"uploaded friend image %@ to server successfully", key);
                                                                                                                                    //get cached image datas
                                                                                                                                    UIImage * image = [[[SDWebImageManager sharedManager] imageCache] imageFromMemoryCacheForKey:key];
                                                                                                                                    NSData * encryptedImageData = [[[SDWebImageManager sharedManager] imageCache] diskImageDataBySearchingAllPathsForKey:key];
                                                                                                                                    
                                                                                                                                    if (image && encryptedImageData) {
                                                                                                                                        //save data for new remote key
                                                                                                                                        [[[SDWebImageManager sharedManager] imageCache] storeImage:image imageData:encryptedImageData mimeType: MIME_TYPE_IMAGE forKey:url
                                                                                                                                                                                            toDisk:YES];
                                                                                                                                        
                                                                                                                                        //remove now defunct cached local data
                                                                                                                                        [[[SDWebImageManager sharedManager] imageCache] removeImageForKey:key fromDisk:YES];
                                                                                                                                        
                                                                                                                                        DDLogInfo(@"key exists for %@: %@", key, [[[SDWebImageManager sharedManager] imageCache] diskImageExistsWithKey:key] ? @"YES" : @"NO" );
                                                                                                                                    }
                                                                                                                                    
                                                                                                                                    [[[ChatManager sharedInstance] getChatController: _username] setFriendImageUrl:url forFriendname:_theirUsername version:_ourVersion iv: b64iv hashed: YES];
                                                                                                                                }
                                                                                                                                else {
                                                                                                                                    DDLogInfo(@"uploading friend image to server succeeded but there is no response object, wtf?");
                                                                                                                                    [UIUtils showToastKey:@"could_not_upload_friend_image" duration:2];
                                                                                                                                }
                                                                                                                                
                                                                                                                                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                                                                                                                                    [_popover dismissPopoverAnimated:YES];
                                                                                                                                }
                                                                                                                                
                                                                                                                                
                                                                                                                            } failureBlock:^(NSURLResponse *operation, NSError *error) {
                                                                                                                                [self stopProgress];
                                                                                                                                DDLogInfo(@"uploading friend image %@ to server failed", key);
                                                                                                                                [UIUtils showToastKey:@"could_not_upload_friend_image" duration:2];
                                                                                                                                
                                                                                                                                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                                                                                                                                    [_popover dismissPopoverAnimated:YES];
                                                                                                                                }
                                                                                                                            }];
                                              }
                                              else {
                                                  [self stopProgress];
                                                  [UIUtils showToastKey:@"could_not_upload_friend_image" duration:2];
                                                  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                                                      [_popover dismissPopoverAnimated:YES];
                                                  }
                                              }
                                          }];
    });
}

+(BOOL) startCameraControllerFromViewController: (UIViewController*) controller
                                  usingDelegate: (ImageDelegate *) delegate {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera] == NO)
        || (delegate == nil)
        || (controller == nil))
        return NO;
    
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
    cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    cameraUI.allowsEditing = NO;
    cameraUI.delegate = delegate;
    
    //cameraUI
    delegate.mode = kSurespotImageDelegateModeCapture;
    delegate.controller = controller;
    [controller presentViewController: cameraUI animated: YES completion:nil];
    return YES;
}

+(BOOL) startImageSelectControllerFromViewController: (UIViewController*) controller
                                       usingDelegate: (ImageDelegate *) delegate {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeSavedPhotosAlbum] == NO)
        || (delegate == nil)
        || (controller == nil))
        return NO;
    
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    cameraUI.allowsEditing = NO;
    cameraUI.delegate = delegate;
    delegate.controller = controller;
    delegate.mode = kSurespotImageDelegateModeSelect;
    //cameraUI
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [delegate setPopover: [[UIPopoverController alloc] initWithContentViewController:cameraUI]];
        delegate.popover.delegate = delegate;
        
        CGFloat x =controller.view.bounds.size.width;
        CGFloat y =controller.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        [delegate.popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:delegate.controller.view permittedArrowDirections:0 animated:YES];
    } else {
        [controller presentViewController: cameraUI animated: YES completion:nil];
    }
    
    return YES;
}

+(BOOL) startFriendImageSelectControllerFromViewController: (UIViewController*) controller
                                             usingDelegate: (ImageDelegate *) delegate {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeSavedPhotosAlbum] == NO)
        || (delegate == nil)
        || (controller == nil))
        return NO;
    
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    cameraUI.allowsEditing = YES;
    cameraUI.delegate = delegate;
    delegate.controller = controller;
    delegate.mode = kSurespotImageDelegateModeFriendImage;
    //cameraUI
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [delegate setPopover: [[UIPopoverController alloc] initWithContentViewController:cameraUI]];
        delegate.popover.delegate = delegate;
        
        CGFloat x =controller.view.bounds.size.width;
        CGFloat y =controller.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        [delegate.popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:delegate.controller.view permittedArrowDirections:0 animated:YES];
    } else {
        [controller presentViewController: cameraUI animated: YES completion:nil];
    }
    
    return YES;
}

+(BOOL) startBackgroundImageSelectControllerFromViewController: (IASKAppSettingsViewController*) controller
                                                 usingDelegate: (ImageDelegate *) delegate {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeSavedPhotosAlbum] == NO)
        || (delegate == nil)
        || (controller == nil))
        return NO;
    
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    cameraUI.allowsEditing = NO;
    cameraUI.delegate = delegate;
    delegate.controller = controller;
    delegate.mode = kSurespotImageDelegateModeBackgroundImage;
    //cameraUI
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [delegate setPopover: [[UIPopoverController alloc] initWithContentViewController:cameraUI]];
        delegate.popover.delegate = delegate;
        
        CGFloat x =controller.view.bounds.size.width;
        CGFloat y =controller.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        [delegate.popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:delegate.controller.view permittedArrowDirections:0 animated:YES];
    } else {
        [controller presentViewController: cameraUI animated: YES completion:nil];
    }
    
    return YES;
}


+(UIImage *) scaleImage: (UIImage *) image {
    return [image imageScaledToMaxWidth:100.0 maxHeight:100.0];    
}

- (void)orientationChanged
{
    // if the popover is showing, adjust its position after the re-orientation by presenting it again:
    if (self.popover != nil)  // if the popover is showing (replace with your own test if you wish)
    {
        CGFloat x =self.controller.view.bounds.size.width;
        CGFloat y =self.controller.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        
        [self.popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.controller.view permittedArrowDirections:0 animated:YES];
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.popover = nil;
}

-(void) startProgress {
    NSDictionary* userInfo = @{@"key": @"imageDelegate"};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"startProgress" object: self userInfo:userInfo];
}

-(void) stopProgress {
    NSDictionary* userInfo = @{@"key": @"imageDelegate"};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"stopProgress" object: self userInfo: userInfo];
    
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return 1;
}

- (MWPhoto *)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index == 0 && _selectedImage)
        return [[MWPhoto alloc] initWithImage:_selectedImage];
    return nil;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser actionButtonPressedForPhotoAtIndex:(NSUInteger)index {
    [self.controller.navigationController popViewControllerAnimated:YES];
    [self uploadImage:_selectedImageUrl];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
}

-(void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView *__autoreleasing *)view {
    CGFloat x = [*view bounds].size.width;
    CGFloat y = [*view bounds].size.height;
    DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
    
    CGRect newRect = CGRectMake(x/2,y/2, 1,1 );
    *rect = newRect;
}


@end
