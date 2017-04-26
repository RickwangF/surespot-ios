//
//  SendMessageOperation.h
//  surespot
//
//  Created by Adam on 4/26/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#ifndef SendMessageOperation_h
#define SendMessageOperation_h

#import "SurespotMessage.h"
#import "SurespotConstants.h"

@interface SendMessageOperation : NSOperation
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@property (nonatomic, strong) CallbackBlock callback;
@property (strong, atomic) NSTimer * bgSendTimer;
@property (assign, atomic) NSInteger bgSendRetries;
-(id) initWithMessage: (SurespotMessage *) message
             callback: (CallbackBlock) callback;
@property (nonatomic) SurespotMessage * message;
-(void) prepAndSendMessage;
-(void) scheduleRetrySend;
- (void)finish: (SurespotMessage *) message;
@end


#endif /* SendMessageOperation_h */
