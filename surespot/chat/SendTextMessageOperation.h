//
//  SendTextMessageOperation.h
//  surespot
//
//  Created by Adam on 4/21/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#ifndef SendTextMessageOperation_h
#define SendTextMessageOperation_h

#import "SurespotMessage.h"
#import "SurespotConstants.h"

@interface SendTextMessageOperation : NSOperation
-(id) initWithMessage: (SurespotMessage *) message
             username: (NSString *) ourUsername
             callback: (CallbackBlock) callback;
@end


#endif /* SendTextMessageOperation_h */
