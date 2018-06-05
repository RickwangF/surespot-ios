//
//  VoiceMessagePlayedDelegate.h
//  surespot
//
//  Created by Adam on 6/5/18.
//  Copyright © 2018 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotMessage.h"

@protocol VoiceMessagePlayedDelegate <NSObject>
-(void) voiceMessagePlayed: (SurespotMessage *) message;
@end
