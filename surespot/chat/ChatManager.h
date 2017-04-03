//
//  ChatManager.h
//  surespot
//
//  Created by Adam on 4/2/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#ifndef ChatManager_h
#define ChatManager_h

#import "ChatController.h"

@interface ChatManager : NSObject
+(ChatManager *) sharedInstance;
-(ChatController *) getChatController: (NSString *) username;
-(ChatController *) getChatControllerIfPresent: (NSString *) username;
-(void) pause: (NSString *) username;
-(void) resume: (NSString *) username;
@end

#endif /* ChatManager_h */
