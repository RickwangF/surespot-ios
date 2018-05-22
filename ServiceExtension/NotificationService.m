//
//  NotificationService.m
//  ServiceExtension
//
//  Created by Adam on 5/21/18.
//  Copyright © 2018 surespot. All rights reserved.
//

#import "NotificationService.h"
#import "CocoaLumberjack.h"
#import "DDTTYLogger.h"


#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif


@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    
    NSUserDefaults * sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.twofours.surespot"];
    NSInteger badge = [sharedDefaults integerForKey:@"badge"];
    badge++;
    [sharedDefaults setInteger:badge forKey:@"badge"];
    
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    DDLogDebug(@"NotificationService, %@", self.bestAttemptContent.userInfo);
    
    NSString * notificationType =[self.bestAttemptContent.userInfo valueForKeyPath:@"aps.alert.loc-key" ] ;
    if ([notificationType isEqualToString:@"notification_message"] ||
        [notificationType isEqualToString:@"notification_invite"]  ||
        [notificationType isEqualToString:@"notification_invite_accept"]) {
        //if we're not logged in as the user add a local notifcation and show a toast
        
        NSArray * locArgs =[self.bestAttemptContent.userInfo valueForKeyPath:@"aps.alert.loc-args" ] ;
        NSString * to =[locArgs objectAtIndex:0];
      //  NSString * from =[locArgs objectAtIndex:1];
        
      //  self.bestAttemptContent.subtitle = [NSString stringWithFormat: NSLocalizedString(notificationType, nil), to];
        self.bestAttemptContent.body = [NSString stringWithFormat: NSLocalizedString(notificationType, nil), to];
       // self.bestAttemptContent.title = NSLocalizedString(@"notification_title", nil);
        
        
        // Modify the notification content here...
        //TODO get the unread message count
        self.bestAttemptContent.badge = [NSNumber numberWithInteger: badge];
        //  self.bestAttemptContent.title = [NSString stringWithFormat:@"%@ [modified]",
        //self.bestAttemptContent.title];
        self.contentHandler(self.bestAttemptContent);
    }
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    self.contentHandler(self.bestAttemptContent);
}

@end
