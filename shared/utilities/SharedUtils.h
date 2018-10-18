//
//  SharedUtilities.m
//  surespot
//
//  Created by Adam on 5/23/18.
//  Copyright © 2018 surespot. All rights reserved.
//
//  Code shared with ServiceExtension
//

#import <Foundation/Foundation.h>

@interface SharedUtils : NSObject
+(NSNumber *) incrementBadgeCount;
+(void) clearBadgeCount;
+(NSInteger) getBadgeCount;
+(void) setCurrentUser: (NSString *) currentUser;
+(void) setCurrentTab: (NSString *) currentTab;
+(NSString *) getCurrentUser;
+(NSString *) getCurrentTab;
+(BOOL) isActive;
+(void) setActive: (BOOL) isActive;
+(void) setMute: (BOOL) mute forUsername: (NSString *) username friendName: (NSString *) friendname;
+(BOOL) getMuteForUsername: (NSString *) username friendName: (NSString *) friendname;

@end
