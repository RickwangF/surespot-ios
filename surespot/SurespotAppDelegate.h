//
//  SurespotAppDelegate.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AGWindowView.h"
#import <AppAuth/AppAuth.h>

@interface SurespotAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIImageView *imageView;
@property(nonatomic, nullable) id<OIDAuthorizationFlowSession> currentAuthorizationFlow;

//@property (strong, nonatomic) AGWindowView * overlayView;
//@property (strong, nonatomic) UIWindow * overlayWindow;
@end
