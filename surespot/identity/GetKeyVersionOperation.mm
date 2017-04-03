//
//  getKeyVersionOperation.m
//  surespot
//
//  Created by Adam on 11/12/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "GetKeyVersionOperation.h"
#import "NetworkManager.h"
#import "EncryptionController.h"
#import "CocoaLumberjack.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif


@interface GetKeyVersionOperation()
@property (nonatomic) CredentialCachingController * cache;
@property (nonatomic, strong) NSString * ourUsername;
@property (nonatomic, strong) NSString * theirUsername;
@property (nonatomic, strong) CallbackStringBlock callback;
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end




@implementation GetKeyVersionOperation

-(id) initWithCache: (CredentialCachingController *) cache ourUsername: (NSString *) ourUsername theirUsername: (NSString *) theirUsername completionCallback: (CallbackStringBlock)  callback {
    

    if (self = [super init]) {
        self.cache = cache;
        self.callback = callback;
        self.ourUsername = ourUsername;
        self.theirUsername = theirUsername;
        
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    NSString * latestVersion = [_cache.latestVersionsDict objectForKey:_theirUsername];
    if (!latestVersion) {
        
        [[[NetworkManager sharedInstance] getNetworkController:_ourUsername]
         getKeyVersionForUsername: _theirUsername
         successBlock:^(NSURLSessionTask *operation, id responseObject) {
             NSString * responseObjectS =   [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
             DDLogVerbose(@"caching key version: %@ for username: %@", responseObjectS, _theirUsername);
             
             [_cache.latestVersionsDict setObject:responseObjectS forKey:_theirUsername];
             [_cache saveLatestVersions];
             [self finish:responseObjectS];
             
         }
         failureBlock:^(NSURLSessionTask *operation, NSError *Error) {
             
             DDLogVerbose(@"response failure: %@",  Error);
             [self finish:nil];
             
         }];
    }
    else {
        DDLogVerbose(@"returning cached key version: %@ for user: %@", latestVersion, _theirUsername);
        [self finish: latestVersion];
    }


    
}

- (void)finish: (NSString *) version
{
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    _callback(version);
    _callback = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
