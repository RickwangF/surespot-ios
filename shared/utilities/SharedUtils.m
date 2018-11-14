//
//  SharedUtils.m
//  surespot
//
//  Created by Adam on 5/23/18.
//  Copyright © 2018 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharedUtils.h"

@implementation SharedUtils
+(NSUserDefaults *) getSharedDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName:@"group.com.twofours.surespot"];
}
+(NSNumber *) incrementBadgeCount {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    NSInteger badge = [sharedDefaults integerForKey:@"badgeCount"];
    NSLog(@"got badge count %ld", (long)badge);
    ++badge;
    [sharedDefaults setInteger:badge forKey:@"badgeCount"];
    NSLog(@"incremented badge count to %ld", (long)badge);
    return [NSNumber numberWithInteger: badge];
}
+(void) clearBadgeCount {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    [sharedDefaults removeObjectForKey:@"badgeCount"];
    NSLog(@"cleared badge count");
}
+(NSInteger) getBadgeCount {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    NSInteger badge = [sharedDefaults integerForKey:@"badgeCount"];
    return badge;
}
+(void) setCurrentUser: (NSString *) currentUser {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
   [sharedDefaults setValue:currentUser forKey:@"currentUser"];
}
+(void) setCurrentTab: (NSString *) currentTab {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    [sharedDefaults setValue:currentTab forKey:@"currentTab"];
}
+(NSString *) getCurrentUser {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    return [sharedDefaults stringForKey:@"currentUser"];
}
+(NSString *) getCurrentTab {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    return [sharedDefaults stringForKey:@"currentTab"];
}
+(BOOL) isActive {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    return [sharedDefaults boolForKey:@"isActive"];
}

+(void) setActive: (BOOL) isActive {
        NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    [sharedDefaults setBool:isActive forKey:@"isActive"];
}

+(void) setMute: (BOOL) mute forUsername: (NSString *) username friendName: (NSString *) friendname {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    NSString * key = [NSString stringWithFormat:@"mute_%@:%@", username, friendname];
    if (mute) {
        [sharedDefaults setBool:YES forKey: key];
    }
    else {
        [sharedDefaults removeObjectForKey:key];
    }
}

+(BOOL) getMuteForUsername: (NSString *) username friendName: (NSString *) friendname {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    NSString * key = [NSString stringWithFormat:@"mute_%@:%@", username, friendname];
    return [sharedDefaults boolForKey:key];
}

+(void) setAlias: (NSString *) alias forUsername: (NSString *) username friendName: (NSString *) friendname {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    NSString * key = [NSString stringWithFormat:@"alias_%@:%@", username, friendname];
    [sharedDefaults setObject:alias forKey: key];
}

+(NSString *) getAliasForUsername: (NSString *) username friendName: (NSString *) friendname {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    NSString * key = [NSString stringWithFormat:@"alias_%@:%@", username, friendname];
    return [sharedDefaults stringForKey:key];
}

+(void) removeAliasForUsername: (NSString *) username friendName: (NSString *) friendname {
    NSUserDefaults * sharedDefaults = [self getSharedDefaults];
    NSString * key = [NSString stringWithFormat:@"alias_%@:%@", username, friendname];
    [sharedDefaults removeObjectForKey:key];
}

@end
