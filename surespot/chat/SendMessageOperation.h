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
-(id) initWithMessage: (SurespotMessage *) message
             username: (NSString *) ourUsername
             callback: (CallbackBlock) callback;
@property (nonatomic) SurespotMessage * message;
-(void) prepAndSendMessage;
@end


#endif /* SendMessageOperation_h */
