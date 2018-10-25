//
//  UIUtils.m
//  surespot
//
//  Created by Adam on 11/1/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//


#import <AssetsLibrary/AssetsLibrary.h>
#import "UIUtils.h"
#import "Toast+UIView.h"
#import "ChatUtils.h"
#import "CocoaLumberjack.h"
#import "SurespotConstants.h"
#import "SurespotAppDelegate.h"
#import "FileController.h"
#import "SDWebImageManager.h"
#import "NSBundle+FallbackLanguage.h"
#import "IdentityController.h"
#import "UIImage+Scale.h"
#import "UIAnyLevelWindow.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

#define ARC4RANDOM_MAX      0x100000000

@implementation UIUtils

+(UIColor *) surespotBlue {
    return [UIColor colorWithRed:0.2 green:0.71 blue:0.898 alpha:1.0];
}

+(UIColor *) surespotSelectionBlue {
    return [UIColor colorWithRed:0.2 green:0.71 blue:0.898 alpha:0.9];
}

+(UIColor *) surespotTransparentBlue {
    return [UIColor colorWithRed:0.2 green:0.71 blue:0.898 alpha:0.5];
}

+(UIColor *) surespotGrey {
    return [UIColor colorWithRed:22/255.0f green:22/255.0f blue:22/255.0f alpha:1.0f];
}

+(UIColor *) surespotForegroundGrey {
    return [UIColor colorWithRed:187/255.0f green:187/255.0f blue:187/255.0f alpha:1.0f];
}


+(UIColor *) surespotTransparentGrey {
    return [UIColor colorWithRed:22/255.0f green:22/255.0f blue:22/255.0f alpha:0.5f];
}

+(UIColor *) surespotSeparatorGrey {
    return [UIColor colorWithRed:180/255.0f green:180/255.0f blue:180/255.0f alpha:0.2f];
}


+(UIWindow *) getHighestLevelWindow {
    UIWindow * theWindowWeWillUse;
    UIWindowLevel theMaxLevelWeFoundWhileIteratingThroughTheseWindowsTryingToReverseEngineerWTFIsGoingOn = 0;
    for (UIWindow * window in [UIApplication sharedApplication].windows) {
        DDLogDebug(@"isKeyWindow = %d window level = %.1f frame = %@ hidden = %d class = %@\n",
                   window.isKeyWindow, window.windowLevel,
                   NSStringFromCGRect(window.frame),window.hidden, window.class.description);
        if (window.windowLevel>=theMaxLevelWeFoundWhileIteratingThroughTheseWindowsTryingToReverseEngineerWTFIsGoingOn && !window.hidden) {
            theMaxLevelWeFoundWhileIteratingThroughTheseWindowsTryingToReverseEngineerWTFIsGoingOn = window.windowLevel;
            theWindowWeWillUse = window;
            DDLogDebug(@"This is the window we shall use");
        }
    }
    
    return theWindowWeWillUse;
}

+(void)showAlertController: (UIAlertController *) controller window: (UIWindow *) window
{
    UIWindow * alertWindow = [[UIAnyLevelWindow alloc] initWithFrame: [UIScreen mainScreen].bounds window: window];
    alertWindow.rootViewController = [UIViewController new];
    [alertWindow setHidden: NO];
    [alertWindow.rootViewController presentViewController: controller animated: YES completion: nil];
}

+(void) showToastMessage: (NSString *) message duration: (CGFloat) duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        AGWindowView * overlayView = [[AGWindowView alloc] initAndAddToKeyWindow];
        [overlayView setUserInteractionEnabled:NO];
        [overlayView  makeToast:message
                       duration: duration
                       position:@"center"
         ];
    });
}

+(void) showToastKey: (NSString *) key {
    [self showToastKey:key duration:2.0];
}

+(void) showToastKey: (NSString *) key duration: (CGFloat) duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        AGWindowView * overlayView = [[AGWindowView alloc] initAndAddToKeyWindow];
        [overlayView setUserInteractionEnabled:NO];
        [overlayView  makeToast:NSLocalizedString(key, nil)
                       duration: duration
                       position:@"center"
         ];
    });
}

+ (void)setAppAppearances {
    [[UINavigationBar appearance] setBarTintColor: [self surespotGrey]];
    
    [[UIBarButtonItem appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys: [self surespotBlue],  NSForegroundColorAttributeName,nil] forState:UIControlStateNormal];
    
    [[UIButton appearance] setTitleColor:[self surespotBlue] forState:UIControlStateNormal];
    
    [[UINavigationBar appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys: [UIUtils surespotForegroundGrey],  NSForegroundColorAttributeName,nil]];
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    
    [[UIScrollView appearance] setIndicatorStyle: ([self isBlackTheme] ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack) ];
    
    [[UISwitch appearance] setTintColor:[UIUtils surespotBlue]];
    [[UISwitch appearance] setOnTintColor:[UIUtils surespotBlue]];
}

+(BOOL)stringIsNilOrEmpty:(NSString*)aString {
    return !(aString && aString.length);
}


+(CGSize) sizeAdjustedForOrientation: (CGSize) size {
    UIInterfaceOrientation  orientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
        DDLogVerbose(@"sizeAdjustedForOrientation adjusting size for landscape");
        return CGSizeMake(size.height, size.width);
    }
    else {
        DDLogVerbose(@"sizeAdjustedForOrientation using size for portrait");
        return CGSizeMake(size.width, size.height);
    }
}


+(void) setImageMessageHeights: (SurespotMessage *)  message {
    NSInteger height = [self getDefaultImageMessageHeight];
    
    [message setRowPortraitHeight: height];
    [message setRowLandscapeHeight: height];
    DDLogVerbose(@"setting image row height portrait %ld landscape %ld", (long)message.rowPortraitHeight, (long)message.rowLandscapeHeight);    
}

+(NSInteger) getDefaultImageMessageHeight {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return 448;
    }
    else {
        return 224;
    }
    
}

+(CGSize)imageSizeAfterAspectFit:(UIImageView*)imgview{
    
    
    float newwidth;
    float newheight;
    
    UIImage *image=imgview.image;
    
    if (image.size.height>=image.size.width){
        newheight=imgview.frame.size.height;
        newwidth=(image.size.width/image.size.height)*newheight;
        
        if(newwidth>imgview.frame.size.width){
            float diff=imgview.frame.size.width-newwidth;
            newheight=newheight+diff/newheight*newheight;
            newwidth=imgview.frame.size.width;
        }
        
    }
    else{
        newwidth=imgview.frame.size.width;
        newheight=(image.size.height/image.size.width)*newwidth;
        
        if(newheight>imgview.frame.size.height){
            float diff=imgview.frame.size.height-newheight;
            newwidth=newwidth+diff/newwidth*newwidth;
            newheight=imgview.frame.size.height;
        }
    }
    
    NSLog(@"image after aspect fit: width=%f height=%f",newwidth,newheight);
    
    
    //adapt UIImageView size to image size
    //imgview.frame=CGRectMake(imgview.frame.origin.x+(imgview.frame.size.width-newwidth)/2,imgview.frame.origin.y+(imgview.frame.size.height-newheight)/2,newwidth,newheight);
    
    return CGSizeMake(newwidth, newheight);
    
}


+(void) setVoiceMessageHeights: (SurespotMessage *) message {
    [message setRowPortraitHeight: 64];
    [message setRowLandscapeHeight: 64];
    DDLogVerbose(@"setting voice row height portrait %ld landscape %ld", (long)message.rowPortraitHeight, (long)message.rowLandscapeHeight);
}



+(void) startSpinAnimation: (UIView *) view {
    CABasicAnimation *rotation;
    rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    rotation.fromValue = [NSNumber numberWithFloat:0];
    rotation.toValue = [NSNumber numberWithFloat:(2*M_PI)];
    rotation.duration = 1.1; // Speed
    rotation.repeatCount = HUGE_VALF; //
    [view.layer addAnimation:rotation forKey:@"spin"];
}

+(void) stopSpinAnimation: (UIView *) view {
    [view.layer removeAnimationForKey:@"spin"];
}

+(void) startPulseAnimation: (UIView *) view {
    CABasicAnimation *theAnimation;
    
    theAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"];
    theAnimation.duration=1.0;
    theAnimation.repeatCount=HUGE_VALF;
    theAnimation.autoreverses=YES;
    theAnimation.fromValue=[NSNumber numberWithFloat:1.0];
    theAnimation.toValue=[NSNumber numberWithFloat:0.33];
    [view.layer addAnimation:theAnimation forKey:@"pulse"];
}

+(void) stopPulseAnimation: (UIView *) view {
    [view.layer removeAnimationForKey:@"pulse"];
}

+(NSString *) getMessageErrorText: (NSInteger) errorStatus mimeType: (NSString *) mimeType {
    NSString * statusText = nil;
    switch (errorStatus) {
        case 400:
            statusText = NSLocalizedString(@"error_message_generic",nil);
            break;
        case 403:
            statusText =  NSLocalizedString(@"message_error_unauthorized",nil);
            break;
        case 404:
            statusText =  NSLocalizedString(@"message_error_unauthorized",nil);
            break;
        case 429:
            statusText =  NSLocalizedString(@"error_message_throttled",nil);
            break;
        case 500:
        default:
            if ([mimeType isEqualToString:MIME_TYPE_TEXT] || [mimeType isEqualToString:MIME_TYPE_GIF_LINK]) {
                statusText =  NSLocalizedString(@"error_message_generic",nil);
            }
            else {
                if([mimeType isEqualToString:MIME_TYPE_IMAGE] || [mimeType isEqualToString:MIME_TYPE_M4A]) {
                    statusText = NSLocalizedString(@"error_message_resend",nil);
                }
            }
            
            break;
    }
    
    return statusText;
}


+(REMenu *) createMenu: (NSArray *) menuItems closeCompletionHandler: (void (^)(void))completionHandler {
    REMenu * menu = [[REMenu alloc] initWithItems:menuItems];
    menu.itemHeight = 40;
    menu.backgroundColor = [UIUtils surespotGrey];
    menu.imageOffset = CGSizeMake(10, 0);
    menu.textAlignment = NSTextAlignmentLeft;
    menu.textColor = [UIUtils surespotForegroundGrey];
    menu.highlightedTextColor = [UIColor whiteColor];
    menu.highlightedBackgroundColor = [UIUtils surespotTransparentBlue];
    menu.textShadowOffset = CGSizeZero;
    menu.highlightedTextShadowOffset = CGSizeZero;
    menu.textOffset =CGSizeMake(64,0);
    menu.font = [UIFont systemFontOfSize:18.0];
    menu.cornerRadius = 4;
    menu.bounce = NO;
    [menu setCloseCompletionHandler:completionHandler];
    return menu;
}

+(void) setLinkLabel:(TTTAttributedLabel *) label
            delegate: (id) delegate
           labelText: (NSString *) labelText
      linkMatchTexts: (NSArray *) linkMatchTexts
          urlStrings: (NSArray *) urlStrings  {
    
    label.delegate = delegate;
    label.text = labelText;
    
    if (linkMatchTexts.count != urlStrings.count) {
        NSException * e = [NSException exceptionWithName:@"IllegalArgumentException" reason:@"match and url count does not match" userInfo:nil];
        [e raise];
    }
    
    for (NSInteger i = 0;i<linkMatchTexts.count;i++) {
        NSString * linkMatchText = linkMatchTexts[i];
        NSString * urlString = [urlStrings[i] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSRange range = [label.text rangeOfString:linkMatchText];
        
        label.linkAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[UIUtils surespotBlue], kCTForegroundColorAttributeName, [NSNumber numberWithInt:kCTUnderlineStyleSingle], kCTUnderlineStyleAttributeName, nil];
        
        [label addLinkToURL:[NSURL URLWithString:urlString] withRange:range];
    }
    
}


+(BOOL) getBoolPrefWithDefaultYesForUser: (NSString *) username key:(NSString *) key {
    //if the pref is not set then default to yes
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    key = [username stringByAppendingString:key];
    NSNumber * value = [defaults objectForKey:key];
    
    if (!value) return YES;
    
    return [value boolValue];
}

+(BOOL) getBoolPrefWithDefaultNoForUser: (NSString *) username key:(NSString *) key {
    //if the pref is not set then default to yes
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    key = [username stringByAppendingString:key];
    NSNumber * value = [defaults objectForKey:key];
    
    if (!value) return NO;
    
    return [value boolValue];
}

+(void) clearLocalCache {
    [FileController wipeAllState];
    [[[SDWebImageManager sharedManager] imageCache] clearMemory];
    [[[SDWebImageManager sharedManager] imageCache] clearDisk];
}

+ (NSString *) buildAliasStringForUsername: (NSString *) username alias: (NSString *) alias {
    return (alias ? [NSString stringWithFormat:@"%@ (%@)", alias, username] : username);
}

+ (NSString *)localizedStringForKey:(NSString *)key replaceValue:(NSString *)replaceValue bundle: (NSBundle *) bundle table: (NSString *) table {
    
    NSString *localizedString = [bundle localizedStringForKey:key value:@"" table:table];
    
    NSArray *preferredLanguagesIncDefault = [NSLocale preferredLanguages];
    NSString * preferredLanguage = [preferredLanguagesIncDefault objectAtIndex:0];
    NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:preferredLanguage];
    NSString *languageCode = [languageDic objectForKey:@"kCFLocaleLanguageCodeKey"];
    //
    //  DDLogInfo(@"localizedStringForKey: %@, preferred language: %@", key, languageCode);
    
    //if we found it or default language is english return it
    if ([languageCode isEqualToString:@"en"] || ![localizedString isEqualToString:key]) {
        //    DDLogInfo(@"localizedStringForKey: %@ found", key);
        return localizedString;
    }
    
    //didn't find it in default
    //iterate through preferred languages till we find a string
    //return english if we don't
    //already tested first language as it's the default so lop that off
    NSMutableArray *preferredLanguages = [NSMutableArray arrayWithArray:preferredLanguagesIncDefault];
    [preferredLanguages removeObjectAtIndex:0];
    
    //TODO revisit if we want to utilize country specific languages
    NSArray *supportedLanguages = [NSArray arrayWithObjects:@"en",@"de",@"it",@"es",@"fr", nil];
    
    for (NSString * language in preferredLanguages) {
        
        //add languages only
        
        NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:language];
        NSString *languageCode = [languageDic objectForKey:@"kCFLocaleLanguageCodeKey"];
        //    NSString *countryCode = [languageDic objectForKey:@"kCFLocaleCountryCodeKey"];
        
        //if we don't support the language don't bother looking
        if (![supportedLanguages containsObject:languageCode]) {
            //        DDLogInfo(@"localizedStringForKey: %@ no fallback translation for languageCode: %@",key, languageCode);
            continue;
        }
        
        NSString *fallbackBundlePath = [bundle pathForResource:languageCode ofType:@"lproj"];
        NSBundle *fallbackBundle = [NSBundle bundleWithPath:fallbackBundlePath];
        NSString *fallbackString = [fallbackBundle localizedStringForKey:key value:@"" table:table];
        if (fallbackString) {
            localizedString = fallbackString;
        }
        if (![localizedString isEqualToString:key]) {
            DDLogInfo(@"localizedStringForKey: %@ found fallback translation for languageCode: %@",key, languageCode);
            break;
        }
        
    }
    //if we didn't find it return english
    if ([localizedString isEqualToString:key]) {
        DDLogInfo(@"localizedStringForKey: %@ falling back to english", key);
        NSString *fallbackBundlePath = [bundle pathForResource:@"en" ofType:@"lproj"];
        NSBundle *fallbackBundle = [NSBundle bundleWithPath:fallbackBundlePath];
        NSString *fallbackString = [fallbackBundle localizedStringForKey:key value:replaceValue table:table];
        localizedString = fallbackString;
    }
    
    return localizedString;
    
}

+(NSString *) ensureGiphyLang {
    NSString * giphyLang = [[NSUserDefaults standardUserDefaults] objectForKey:@"pref_giphy_lang"];
    if (!giphyLang) {
        
        NSArray *preferredLanguagesIncDefault = [NSLocale preferredLanguages];
        NSString * preferredLanguage = [preferredLanguagesIncDefault objectAtIndex:0];
        NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:preferredLanguage];
        NSString * desiredLang = [languageDic objectForKey:@"kCFLocaleLanguageCodeKey"];
        
        NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"InAppSettings" ofType:@"bundle"];
        if(!settingsBundle) {
            NSLog(@"Could not find Settings.bundle");
            return nil;
        }
        
        NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"global_options.plist"]];
        NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
        for(NSDictionary *prefSpecification in preferences) {
            NSString *key = [prefSpecification objectForKey:@"Key"];
            if([key isEqualToString:@"pref_giphy_lang"]) {
                NSArray * values = [prefSpecification objectForKey:@"Values"];
                if ([values containsObject:desiredLang]) {
                    giphyLang = desiredLang;
                    break;
                }
            }
        }
        
        if (!giphyLang) {
            giphyLang = @"en";
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:giphyLang forKey:@"pref_giphy_lang"];
    }
    return giphyLang;
}

+(BOOL) isBlackTheme {
    NSNumber * value = [[NSUserDefaults standardUserDefaults] objectForKey:@"pref_black_theme"];
    if (!value) return YES;
    return [value boolValue];
}

+(BOOL) confirmLogout {
    NSNumber * value = [[NSUserDefaults standardUserDefaults] objectForKey:@"pref_confirm_logout"];
    if (!value) return YES;
    return [value boolValue];
}

+(void) setTextFieldColors: (UITextField *) textField localizedStringKey: (NSString *) key {
    if ([self isBlackTheme]) {
        [textField setTextColor: [UIUtils surespotForegroundGrey]];
        [textField setAttributedPlaceholder: [[NSAttributedString alloc]
                                              initWithString:NSLocalizedString(key, nil)
                                              attributes:@{NSForegroundColorAttributeName:[UIUtils surespotForegroundGrey]}]];
        [textField.layer setBorderColor:[[UIUtils surespotGrey] CGColor]];
        [textField.layer setBorderWidth:1.0f];
    }
}

+(double) generateIntervalK: (double) k maxInterval: (double) maxInterval {
    double timerInterval = pow(2,k);
    
    if (timerInterval > maxInterval) {
        timerInterval = maxInterval;
    }
    
    double mult = ((double)arc4random() / ARC4RANDOM_MAX);
    double reconnectTime = mult * timerInterval;
    return reconnectTime;
}

+(void) getLocalImageFromAssetUrlOrId: (NSString *) urlOrId callback:(CallbackBlock) callback {
    if ([urlOrId hasPrefix:@"assets-library://"]) {
        ALAssetsLibrary* assetsLibrary = [[ALAssetsLibrary alloc] init];
        [assetsLibrary assetForURL:[NSURL URLWithString: urlOrId] resultBlock:^(ALAsset *asset) {
            ALAssetRepresentation *rep = [asset defaultRepresentation];
            @autoreleasepool {
                CGImageRef iref = [rep fullResolutionImage];
                if (iref) {
                    UIImage *image = [UIImage imageWithCGImage:iref
                                                         scale:1
                                                   orientation:(UIImageOrientation)[rep orientation]];
                    
                    iref = nil;
                    UIImage * scaledImage = [image imageScaledToMaxWidth:400 maxHeight:400];
                    callback(scaledImage);
                }
                else {
                    callback(nil);
                }
            }
        } failureBlock:^(NSError *error) {
            callback(nil);
        }];
    }
    else {
        //local id from PHAsset
        PHFetchResult * result = [PHAsset fetchAssetsWithLocalIdentifiers:@[urlOrId] options:nil];
        PHContentEditingInputRequestOptions * options = [PHContentEditingInputRequestOptions new];
        options.networkAccessAllowed = YES;
        [[result firstObject] requestContentEditingInputWithOptions:options completionHandler:^(PHContentEditingInput * _Nullable contentEditingInput, NSDictionary * _Nonnull info) {
            callback([[contentEditingInput displaySizeImage] imageScaledToMaxWidth:400 maxHeight:400]);
        }];
    }
}

+(void) ensureSurespotAssetCollectionCompletionHandler:(void (^)(PHAssetCollection * collection)) completionHandler {
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.predicate = [NSPredicate predicateWithFormat:@"title = %@", @"surespot"];
    __block PHAssetCollection * collection = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                                      subtype:PHAssetCollectionSubtypeAny
                                                                                      options:fetchOptions].firstObject;
    
    // Create the album
    if (!collection)
    {
        __block PHObjectPlaceholder *placeHolder;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCollectionChangeRequest *createAlbum = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:@"surespot"];
            placeHolder = [createAlbum placeholderForCreatedAssetCollection];
        } completionHandler:^(BOOL success, NSError *error) {
            if (success)
            {
                PHFetchResult *collectionFetchResult = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[placeHolder.localIdentifier]
                                                                                                            options:nil];
                collection = collectionFetchResult.firstObject;
            }
            
            if (completionHandler) {
                completionHandler(collection);
            }
        }];
    }
    else {
        if (completionHandler) {
            completionHandler(collection);
        }
    }
}

+(void) saveImage: (UIImage *) image completionHandler:(void (^)(NSString * localIdentifier)) completionHandler {
    [self ensureSurespotAssetCollectionCompletionHandler:^(PHAssetCollection *collection) {
        if (collection) {
            __block PHObjectPlaceholder *placeHolder;
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                placeHolder = [assetRequest placeholderForCreatedAsset];
                PHFetchResult *photosAsset = [PHAsset fetchAssetsInAssetCollection:collection options:nil];
                PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:collection
                                                                                                                              assets:photosAsset];
                [albumChangeRequest addAssets:@[placeHolder]];
            } completionHandler:^(BOOL success, NSError *error) {
                if (success)
                {
                    if (completionHandler) {
                        completionHandler(placeHolder.localIdentifier);
                    }
                }
                else
                {
                    if (completionHandler) {
                        completionHandler(nil);
                    }
                }
            }];
        }
        else {
            if (completionHandler) {
                completionHandler(nil);
            }
        }
    }];
}



+(void) showPasswordAlertTitle: (NSString *) title
                       message: (NSString *) message
                    controller: (UIViewController *) controller
                      callback: (CallbackBlock) callback {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"password", nil);
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.secureTextEntry = YES;
    }];
    
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action) {
                                                         NSArray * textfields = alert.textFields;
                                                         UITextField * passwordfield = textfields[0];
                                                         NSString * password = [passwordfield text];
                                                         callback(password);
                                                     }];
    
    [alert addAction:okAction];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alert addAction:cancelAction];
    [controller presentViewController:alert animated:YES completion:nil];
}

+(UIColor*) getTextColor {
    return ([UIUtils isBlackTheme] ? [UIUtils surespotForegroundGrey] : [UIColor blackColor]);
}

@end
