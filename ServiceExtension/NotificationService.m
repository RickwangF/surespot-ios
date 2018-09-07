//
//  NotificationService.m
//  ServiceExtension
//
//  Created by Adam on 5/21/18.
//  Copyright © 2018 surespot. All rights reserved.
//

#import "NotificationService.h"
#import "SharedUtils.h"

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    NSLog(@"NotificationService, %@", self.bestAttemptContent.userInfo);
    
    NSString * notificationType =[self.bestAttemptContent.userInfo valueForKeyPath:@"aps.alert.loc-key" ] ;
    if ([notificationType isEqualToString:@"notification_message"] ||
        [notificationType isEqualToString:@"notification_invite"]  ||
        [notificationType isEqualToString:@"notification_invite_accept"]) {
        //if we're not logged in as the user add a local notifcation and show a toast
        
       // NSArray * locArgs =[self.bestAttemptContent.userInfo valueForKeyPath:@"aps.alert.loc-args" ] ;
       // NSString * to =[locArgs objectAtIndex:0];
       // NSString * from =[locArgs objectAtIndex:1];
        
        //if the app is not active increment the badge count
        if (![SharedUtils isActive]) {
            [SharedUtils incrementBadgeCount];
        }
        
        //  self.bestAttemptContent.subtitle = [NSString stringWithFormat: NSLocalizedString(notificationType, nil), to];
        //  self.bestAttemptContent.body = [NSString stringWithFormat: NSLocalizedString(notificationType, nil), to];
        // self.bestAttemptContent.title = NSLocalizedString(@"notification_title", nil);
        
        
        // Modify the notification content here...
        self.bestAttemptContent.badge = [NSNumber numberWithInteger: [SharedUtils getBadgeCount]];
        //        self.bestAttemptContent.sound = [UNNotificationSound defaultSound];
        //        self.bestAttemptContent.sound = [UNNotificationSound soundNamed:@"message.caf"];
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
