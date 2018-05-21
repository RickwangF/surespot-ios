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
#import <UserNotifications/UserNotifications.h>

@interface SurespotAppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>

@property (strong, nonatomic) UIWindow * _Nonnull window;
@property (strong, nonatomic) UIImageView * _Nullable imageView;
@property(nonatomic, nullable) id<OIDAuthorizationFlowSession> currentAuthorizationFlow;

@end
