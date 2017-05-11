//
//  SendMessageOperation.mm
//  surespot
//
//  Created by Adam on 4/26/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import "DownloadGifOperation.h"
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

@implementation DownloadGifOperation


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

    [self downloadMessage];
}

-(void) downloadMessage {
    if (_message.plainData) {
        NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
        
        NSURL * url = [NSURL URLWithString:_message.plainData];
        
        NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url
                                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                            
                                                            
                                                            [self finish:data];
                                                            
                                                            
                                                        }];
        
        [dataTask resume];
    }
    else {
        [self finish:nil];
    }
}




- (void)finish: (NSData *) data
{
    DDLogVerbose(@"finished");
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];

    if (_callback) {
        _callback(data);
    }
    _callback = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
