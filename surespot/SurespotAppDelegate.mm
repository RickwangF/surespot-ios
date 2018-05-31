//
//  SurespotAppDelegate.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "SurespotAppDelegate.h"
#import "SurespotMessage.h"
#import "ChatManager.h"
#import "CocoaLumberjack.h"
#import "DDTTYLogger.h"
#import "SurespotLogFormatter.h"
#import "UIUtils.h"
#import "IdentityController.h"
#import "UIUtils.h"
#import <StoreKit/StoreKit.h>
#import "PurchaseDelegate.h"
#import "SoundController.h"
#import "CredentialCachingController.h"
#import "FileController.h"
#import "NSBundle+FallbackLanguage.h"
#import "NetworkManager.h"
#import "SideMenu-Swift.h"
#import <UserNotifications/UserNotifications.h>
#import "ChatUtils.h"
#import "SharedUtils.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface SurespotAppDelegate()
@property NSMutableDictionary * lastUsers;
@end

@implementation SurespotAppDelegate

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    // in our case, show the surespot logo centered on a black background
    
    UIView *colorView = [[UIView alloc] initWithFrame:self.window.frame];
    colorView.tag = 9999;
    colorView.backgroundColor = [UIColor blackColor];
    _imageView = [[UIImageView alloc]initWithFrame:[colorView frame]];
    UIImage * image =[UIImage imageNamed:@"surespotlauncher512.png"];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_imageView setImage:image];
    [colorView addSubview:_imageView];
    [self.window addSubview:colorView];
    [self.window bringSubviewToFront:colorView];
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // remove the surespot logo centered on a black background
    UIView *colorView = [self.window viewWithTag:9999];
    if(_imageView != nil) {
        [_imageView removeFromSuperview];
        _imageView = nil;
    }
    [colorView removeFromSuperview];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _lastUsers = [[NSMutableDictionary alloc] init];
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error)
     {
         if( !error )
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [[UIApplication sharedApplication] registerForRemoteNotifications];
                 // required to get the app to do anything at all about push notifications
             });
             DDLogDebug( @"Push registration success." );
         }
         else
         {
             DDLogDebug( @"Push registration FAILED" );
             DDLogDebug( @"ERROR: %@ - %@", error.localizedFailureReason, error.localizedDescription );
             DDLogDebug( @"SUGGESTIONS: %@ - %@", error.localizedRecoveryOptions, error.localizedRecoverySuggestion );
         }
     }];
    
    
    if  (launchOptions) {
        DDLogVerbose(@"received launch options: %@", launchOptions);
    }
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance]setLogFormatter: [SurespotLogFormatter new]];
    [UIUtils setAppAppearances];
    
    UIStoryboard *storyboard = self.window.rootViewController.storyboard;
    UINavigationController *rootViewController = [storyboard instantiateViewControllerWithIdentifier:@"navigationController"];
    
    [self.window makeKeyAndVisible];
    
    self.window.rootViewController = rootViewController;
    
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    [[NSUserDefaults standardUserDefaults] setObject:appVersionString forKey:@"version_preference"];
    
    
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    [[NSUserDefaults standardUserDefaults] setObject:appBuildString forKey:@"build_preference"];
    
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[PurchaseDelegate sharedInstance]];
    
    //clean up old file locations
    [FileController deleteOldSecrets];
    
    //clear local cache
    BOOL cacheCleared = [[NSUserDefaults standardUserDefaults] boolForKey:@"cacheCleared13"];
    if (!cacheCleared) {
        [UIUtils clearLocalCache];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"cacheCleared13"];
    }
    
    [UIUtils ensureGiphyLang];
    
    //get reachability started
    [ChatManager sharedInstance];
    NSString * lastUser = [[IdentityController sharedInstance] getLastLoggedInUser];
    
    //see if we have a last user
    BOOL setSession = NO;
    
    if (lastUser) {
        setSession = [[CredentialCachingController sharedInstance] setSessionForUsername:lastUser];
    }
    
    if (setSession) {
        [rootViewController setViewControllers:@[[storyboard instantiateViewControllerWithIdentifier:@"swipeViewController"]]];
    }
    
    else {
        //show create if we don't have any identities, otherwise login
        if ([[[IdentityController sharedInstance] getIdentityNames ] count] == 0 ) {
            [rootViewController setViewControllers:@[[storyboard instantiateViewControllerWithIdentifier:@"signupViewController"]]];
        }
        else {
            [rootViewController setViewControllers:@[[storyboard instantiateViewControllerWithIdentifier:@"loginViewController"]]];
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fastUserSwitch:) name:@"fastUserSwitch" object:nil];
    return YES;
}


//launch from smart banner or url
- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<NSString *, id> *)options {
    if (!url) {  return NO; }
    
    DDLogInfo(@"url %@", url);
    
    if ([url.scheme isEqualToString:@"surespot"]) {
        if ([[url host] isEqualToString:@"autoinvite"]) {
            NSString * username = [[url path] substringFromIndex:1];
            
            
            if (username) {
                DDLogInfo(@"adding autoinvite for %@",  username);
                //get autoinvite users
                
                
                NSMutableArray * autoinvites  = [NSMutableArray arrayWithArray: [[NSUserDefaults standardUserDefaults] stringArrayForKey: @"autoinvites"]];
                [autoinvites addObject: username];
                [[NSUserDefaults standardUserDefaults] setObject: autoinvites forKey: @"autoinvites"];
                //fire event
                [[NSNotificationCenter defaultCenter] postNotificationName:@"autoinvites" object:nil ];
                return YES;
            }
        }
    }
    
    if ([_currentAuthorizationFlow resumeAuthorizationFlowWithURL:url]) {
        _currentAuthorizationFlow = nil;
        return YES;
    }
    
    return NO;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification  withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{
    DDLogDebug( @"received notification while in foreground" );
    NSDictionary * userInfo = [NSMutableDictionary dictionaryWithDictionary: notification.request.content.userInfo];
    DDLogDebug(@"%@", notification.request.content);
    
    //if we created the notification locally just show it
    if ([userInfo valueForKey:@"local"] != nil) {
        completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge);
    }
    else {
        //push notification, figure out badge count
        NSString * notificationType =[userInfo valueForKeyPath:@"aps.alert.loc-key" ] ;
        if ([notificationType isEqualToString:@"notification_message"] ||
            [notificationType isEqualToString:@"notification_invite"]  ||
            [notificationType isEqualToString:@"notification_invite_accept"]) {
            
            NSArray * locArgs =[userInfo valueForKeyPath:@"aps.alert.loc-args" ] ;
            NSString * to = [locArgs objectAtIndex:0];
            NSString * from = [locArgs objectAtIndex:1];
            NSString * messageId = [userInfo valueForKey:@"id"];
            
            [userInfo setValue:@"surespotRulez" forKey:@"local"];
            //application was running when we received
            //if we're not on the tab, show notification
            if ([to isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]] &&
                [[[IdentityController sharedInstance] getIdentityNames] containsObject:to]) {
                
                ChatController * cc = [[ChatManager sharedInstance] getChatControllerIfPresent: to];
                //if we're not currently on the tab
                if (![[cc getCurrentChat] isEqualToString:from]) {
                    //get alias
                    Friend * thefriend = [[cc getHomeDataSource] getFriendByName: from];
                    NSString * body;
                    if (thefriend) {
                        body = [NSString stringWithFormat:NSLocalizedString(@"notification_message_from", nil), to,thefriend.nameOrAlias];
                    }
                    else {
                        body = [NSString stringWithFormat: NSLocalizedString(notificationType, nil), to];
                    }
                    
                    UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc] init];
                    [content setBody:body];
                    [content setUserInfo:userInfo];
                    
                    //badge count incremented by extension
                    [content setBadge:[NSNumber numberWithInteger: [SharedUtils getBadgeCount]]];
                    
                    //TODO allow user to choose surespot or system sounds
                    [content setSound: [UNNotificationSound soundNamed:@"message.caf"]];
                    //           [content setBadge: [SharedUtils incrementBadgeCount]];
                    NSString * requestId = [[NSUUID  UUID] UUIDString];
                    // [NSString stringWithFormat:@"%@:%@", to,from];
                    
                    UNNotificationTrigger * trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:.0001 repeats:NO];
                    UNNotificationRequest * request = [UNNotificationRequest requestWithIdentifier:requestId content:content trigger:trigger];
                    
                    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
                    completionHandler(UNNotificationPresentationOptionNone);
                }
            }
        }
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response  withCompletionHandler:(void (^)())completionHandler   {
    DDLogDebug( @"opened from notification" );
    NSDictionary * userInfo = response.notification.request.content.userInfo;
    DDLogDebug(@"%@", userInfo);
    NSArray * locArgs =[userInfo valueForKeyPath:@"aps.alert.loc-args" ] ;
    NSString * to = [locArgs objectAtIndex:0];
    NSString * from = [locArgs objectAtIndex:1];
    
    
    NSString * notificationType =[userInfo valueForKeyPath:@"aps.alert.loc-key" ] ;
    if ([notificationType isEqualToString:@"notification_invite"] || [notificationType isEqualToString:@"notification_invite_accept"]) {
        [[NSUserDefaults standardUserDefaults] setObject:@"invite" forKey:@"notificationType"];
        [[NSUserDefaults standardUserDefaults] setObject:to forKey:@"notificationTo"];
    }
    else {
        if ([notificationType isEqualToString:@"notification_message"]) {
            [[NSUserDefaults standardUserDefaults] setObject:@"message" forKey:@"notificationType"];
            [[NSUserDefaults standardUserDefaults] setObject:to forKey:@"notificationTo"];
            [[NSUserDefaults standardUserDefaults] setObject:from forKey:@"notificationFrom"];
        }
    }
    
    //if it's the same user fire notification
    if ([to isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"openedFromNotification" object:nil ];
    }
    else {
        [self userSwitch:to fromNotification:YES];
    }
    completionHandler();
}

-(void) fastUserSwitch: (NSNotification *) notification {
    [self userSwitch: notification.userInfo[@"username"] fromNotification:NO];
}

-(void) userSwitch: (NSString *) username fromNotification: (BOOL) fromNotification {
    DDLogDebug(@"userSwitch, username: %@, fromNotification: %@", username, (fromNotification ? @"YES" : @"NO"));
    //save current tab
    NSString * currentUser = [[IdentityController sharedInstance] getLoggedInUser];
    ChatController * cc = [[ChatManager sharedInstance] getChatControllerIfPresent: currentUser];
    NSString * currentChat = [cc getCurrentChat];
    if (currentChat && currentUser) {
        [_lastUsers setObject:currentChat forKey:currentUser];
        DDLogDebug(@"userSwitch saving last chat: %@ for user: %@", currentChat, currentUser);
    }
    else {
        if (currentUser) {
            [_lastUsers removeObjectForKey:currentUser];
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"userSwitch" object:nil];
    
    //if we're fast user switching, see if there's a last user and if there is use the switch to notification user functionality to switch to the tab
    if (!fromNotification) {
        NSString * to = username;
        
        //set "notification" defaults to switch back to that user
        [[NSUserDefaults standardUserDefaults] setObject:@"message" forKey:@"notificationType"];
        [[NSUserDefaults standardUserDefaults] setObject:to forKey:@"notificationTo"];
        
        NSString * from = [_lastUsers objectForKey:username];
        if (from) {
            [[NSUserDefaults standardUserDefaults] setObject:from forKey:@"notificationFrom"];
        }
        
        DDLogDebug(@"userSwitch restoring last chat: %@ for user: %@", from, to);
    }
    
    //set the session
    UIStoryboard *storyboard = self.window.rootViewController.storyboard;
    [cc pause];
    if ([[CredentialCachingController sharedInstance] setSessionForUsername:username]) {
        UINavigationController * navController = (UINavigationController *) self.window.rootViewController;
        CATransition* transition = [CATransition animation];
        transition.duration = 0.3;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        transition.type = kCATransitionFade;
        [navController.view.layer addAnimation:transition forKey:nil];
        [[SideMenuManager menuLeftNavigationController] dismissViewControllerAnimated: NO completion:nil];
        UIViewController * c =[storyboard instantiateViewControllerWithIdentifier:@"swipeViewController"];
        [navController setViewControllers:@[c] animated:NO];
    }
    else {
        //show login
        [(UINavigationController *) self.window.rootViewController setViewControllers:@[[storyboard instantiateViewControllerWithIdentifier:@"loginViewController"]]];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    //clear badge count
 //   [SharedUtils setCurrentTab:nil];
    [SharedUtils setActive:NO];
  //  [SharedUtils clearBadgeCount];
   // [[UIApplication sharedApplication] setApplicationIconBadgeNumber: [SharedUtils getBadgeCount]];
    
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    //   DDLogVerbose(@"background");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    //  DDLogVerbose(@"foreground");
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken {
    DDLogDebug(@"didRegisterToken: %@", [ChatUtils hexFromData:devToken]);
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:devToken forKey:@"apnToken"];
    
    //todo set token on server
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    DDLogDebug(@"Error in registration. Error: %@", err);
}

@end
