//
//  ChatManager.m
//  surespot
//
//  Created by Adam on 4/2/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatManager.h"
#import "ChatManager.h"
#import "CocoaLumberjack.h"
#import "SurespotConstants.h"
#import "AFNetworkReachabilityManager.h"
#import "IdentityController.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface ChatManager() {}
@property (strong, atomic) NSMutableDictionary * chatControllers;
@property (strong, atomic) NSString * activeUser;
@property (assign, atomic) AFNetworkReachabilityStatus networkReachabilityStatus;
@end

@implementation ChatManager

+(ChatManager *) sharedInstance {
    static ChatManager *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

-(ChatManager *) init {
    self = [super init];
    
    if (self) {
        _chatControllers = [[NSMutableDictionary alloc] initWithCapacity:MAX_IDENTITIES];
        
        //listen for network changes so we can reconnect
        [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            ChatController * controller = [self getChatController:[[IdentityController sharedInstance] getLoggedInUser]];
            //if we're foregrounded
            if (![controller paused]) {
                BOOL isReachable = status == AFNetworkReachabilityStatusReachableViaWiFi || status == AFNetworkReachabilityStatusReachableViaWWAN;
                
                if(isReachable)
                {
                    
                    DDLogInfo(@"wifi: %d, wwan, %d",status == AFNetworkReachabilityStatusReachableViaWiFi, status == AFNetworkReachabilityStatusReachableViaWWAN);
                    //reachibility changed, disconnect and reconnect
                    if (_networkReachabilityStatus > -1 && status != _networkReachabilityStatus) {
                        DDLogInfo(@"network status changed from %ld to: %ld, disconnecting", (long)_networkReachabilityStatus, (long) status);
                        [controller disconnect];
                    }                    

                    [controller reconnect];
                }
                else
                {
                    DDLogInfo(@"Notification Says Unreachable");
                }
            }
            
            DDLogInfo(@"setting network status from %ld to: %ld", (long)_networkReachabilityStatus, (long) status);
            _networkReachabilityStatus = status;
        }];
        
        [[AFNetworkReachabilityManager sharedManager] startMonitoring];
        _networkReachabilityStatus = [[AFNetworkReachabilityManager sharedManager] networkReachabilityStatus];
        DDLogInfo(@"initial network status: %ld", (long)_networkReachabilityStatus);
        
    }
    
    return self;
}

-(ChatController *) getChatControllerIfPresent: (NSString *) username {
    return [_chatControllers objectForKey:username];
}

-(ChatController *) getChatController: (NSString *) username {
    ChatController * chatController = [_chatControllers objectForKey:username];
    if (!chatController) {
        chatController = [[ChatController alloc] init: username];
        [_chatControllers setObject:chatController forKey:username];
    }
    return chatController;
    
}

-(void) pause: (NSString *) username {
    //don't want to create one
    [[self getChatControllerIfPresent:username] pause];
}

-(void) resume: (NSString *) username {
    _activeUser = username;
    [[self getChatController:username] resume];
}

@end
