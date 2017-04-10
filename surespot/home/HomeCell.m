//
//  HomeCell.m
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "HomeCell.h"
#import "UIUtils.h"
#import "CocoaLumberjack.h"


#ifdef DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif


#define INVITE_ACTION_BLOCK 0;
#define INVITE_ACTION_IGNORE 1;
#define INVITE_ACTION_ACCEPT 2;

@implementation HomeCell



- (IBAction)inviteAction:(UIButton*)sender {
    NSString * action;
    switch ([sender tag]) {
        case 0:
            action = @"block";
            break;
        case 1:
            action = @"ignore";
            break;
        case 2:
            action = @"accept";
            break;
    }
    if (action) {
        
        [_friendDelegate inviteAction:action forUsername:_friendName];
    }
}



@end
