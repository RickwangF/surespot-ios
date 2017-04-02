//
//  NetworkManager.m
//  surespot
//
//  Created by Adam on 4/2/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NetworkManager.h"
#import "CocoaLumberjack.h"
#import "SurespotConstants.h"
#import "AFNetworkReachabilityManager.h"
#import "IdentityController.h"
#import "CredentialCachingController.h"


#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface NetworkManager() {}
@property (strong, atomic) NSMutableDictionary * networkControllers;
@property (strong, atomic) NetworkController * nilController;

@end


@implementation NetworkManager

+(NetworkManager *) sharedInstance {
    static NetworkManager *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

-(NetworkManager *) init {
    self = [super init];
    
    if (self) {
        _networkControllers = [[NSMutableDictionary alloc] initWithCapacity:MAX_IDENTITIES];
        
        
    }
    
    return self;
}

-(NetworkController *) getNetworkController: (NSString *) username {
    if (username) {
    
    NetworkController * networkController = [_networkControllers objectForKey:username];
    if (!networkController) {
        networkController = [[NetworkController alloc] init];
        //set cookie
        [networkController setCookie:[[CredentialCachingController sharedInstance] getCookieForUsername:username]];
        [_networkControllers setObject:networkController forKey:username];
    }
    return networkController;
    }
    else {
        if (!_nilController) {
            _nilController = [[NetworkController alloc] init];
        }
        return _nilController;
    }
}

@end
