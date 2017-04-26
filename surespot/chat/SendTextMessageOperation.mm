//
//  GetPublicKeysOperation.m
//  surespot
//
//  Created by Adam on 10/20/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

//
//  GenerateSharedSecretOperation.m
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//


#import "SendTextMessageOperation.h"
#import "CocoaLumberjack.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import "NetworkManager.h"
#import "UIUtils.h"


#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif





@interface SendTextMessageOperation()
@property (nonatomic) NSString * username;
@property (nonatomic, strong) CallbackBlock callback;
@property (strong, atomic) NSTimer * bgSendTimer;
@property (assign, atomic) NSInteger bgSendRetries;
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end



@implementation SendTextMessageOperation

-(id) initWithMessage: (SurespotMessage *) message
             username: (NSString *) ourUsername
             callback: (CallbackBlock) callback {
    
    if (self = [super init]) {
        self.message = message;
        self.username = ourUsername;
        self.callback = callback;
        
        _isExecuting = NO;
        _isFinished = NO;
        
    }
    return self;
}

-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    DDLogVerbose(@"executing");
    
    [self prepAndSendMessage];
}

-(void) prepAndSendMessage {
    if (![_message readyToSend]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString * ourLatestVersion = [[IdentityController sharedInstance] getOurLatestVersion: _username];
            
            [[IdentityController sharedInstance] getTheirLatestVersionForOurUsername: _username theirUsername: [_message to] callback:^(NSString * version) {
                if (version) {
                    [self encryptMessage:_message ourVersion:ourLatestVersion theirVersion:version callback:^(NSString * cipherText) {
                        if (cipherText) {
                            _message.fromVersion = ourLatestVersion;
                            _message.toVersion = version;
                            _message.data = cipherText;
                            [self sendTextMessageViaHttp];
                        }
                        else {
                            [self scheduleRetrySend];
                        }
                    }];
                }
                else {
                    [self scheduleRetrySend];
                }
            }];
        });
    }
    else {
        [self sendTextMessageViaHttp];
    }
    
}

-(void) encryptMessage: (SurespotMessage *) message
            ourVersion: (NSString *) ourVersion
          theirVersion: (NSString *) theirVersion
              callback: (CallbackBlock) callback {
    [EncryptionController symmetricEncryptString: [message plainData]
                                     ourUsername: _username
                                      ourVersion:ourVersion
                                   theirUsername:[message to]
                                    theirVersion:theirVersion
                                              iv:[message iv]
                                        callback:callback];
}

-(void) sendTextMessageViaHttp {
    NSMutableArray * messagesJson = [[NSMutableArray alloc] init];
    
    
    [messagesJson addObject:[_message toNSDictionary]];
    
    
    [[[NetworkManager sharedInstance] getNetworkController:_username]
     sendMessages:messagesJson
     
     successBlock:^(NSURLSessionTask *task, id JSON) {
         DDLogDebug(@"success sending message via http");
         //iterate through response statuses and handle accordingly
         NSArray * responses = [JSON objectForKey:@"messageStatus"];
         [responses enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary * _Nonnull messageStatus, NSUInteger idx, BOOL * _Nonnull stop) {
             NSInteger status = [[messageStatus objectForKey:@"status"] integerValue];
             dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                 
                 
                 if (status == 204) {
                     SurespotMessage * message = [[SurespotMessage alloc] initWithDictionary:[messageStatus objectForKey:@"message"]];
                     [self finish:message];
                 }
                 else {
                     [self finish:_message];
                 }
             });
         }];
     }
     
     failureBlock:^(NSURLSessionTask *operation, NSError *Error) {
         //todo bail on fatal error
         DDLogDebug(@"failure sending messages via http");
         [self scheduleRetrySend];
     }];
    
}

-(void) scheduleRetrySend {
    [_bgSendTimer invalidate];
    
    if ([self isCancelled] || ++_bgSendRetries >= RETRY_ATTEMPTS) {
        DDLogDebug(@"task cancelled: %@ or reached retry attempt limit: %ld", [NSNumber numberWithBool:[self isCancelled]], (long)_bgSendRetries);
        [self finish:nil];
        return;
    }
    double timerInterval = [UIUtils generateIntervalK: _bgSendRetries maxInterval:RETRY_DELAY];
    DDLogDebug(@ "attempting to send messages via http in: %f" , timerInterval);
    _bgSendTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(bgSendTimerFired:) userInfo:nil repeats:NO];
    
}


-(void) bgSendTimerFired: (NSTimer *) timer {
    [self prepAndSendMessage];
}


- (void)finish: (SurespotMessage *) message
{
    DDLogVerbose(@"finished");
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;

    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    
    [_bgSendTimer invalidate];
    if (_callback) {
        _callback(message);
    }
    _callback = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
