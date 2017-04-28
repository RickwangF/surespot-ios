//
//  SendMessageOperation.mm
//  surespot
//
//  Created by Adam on 4/26/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import "SendMessageOperation.h"
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

@interface SendMessageOperation()
@property (assign, atomic) UIBackgroundTaskIdentifier bgTaskId;
@end

@implementation SendMessageOperation

-(id) initWithMessage: (SurespotMessage *) message
             callback: (CallbackBlock) callback {
    
    if (self = [super init]) {
        self.message = message;
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
    
    _bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
    
    
    [self prepAndSendMessage];
}

-(void) prepAndSendMessage {
    [self doesNotRecognizeSelector: _cmd];
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

//regained network connectivity, try again immediately
-(void) connected {
    DDLogVerbose(@"received connected signal");
    if (_isExecuting) {
        [_bgSendTimer invalidate];
        _bgSendTimer = nil;
        [self prepAndSendMessage];
    }
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
    
    [[UIApplication sharedApplication] endBackgroundTask:_bgTaskId];
    
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
