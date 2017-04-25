//
//  SurespotMessage.h
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "SurespotMessage.h"

@interface SurespotQueueMessage : SurespotMessage
-(id) initFromMessage: (SurespotMessage *) message;
@end
