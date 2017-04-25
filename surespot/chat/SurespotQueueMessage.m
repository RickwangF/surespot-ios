//
//  SurespotMessage.m
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "SurespotQueueMessage.h"
#import "ChatUtils.h"

@implementation SurespotQueueMessage

-(id) initFromMessage: (SurespotMessage *) message {
    self = [super init];
    if (self) {
        self.serverid = message.serverid;
        self.from = message.from;
        self.to = message.to;
        self.iv = message.iv;
        self.data  = message.data;
        self.toVersion = message.toVersion;
        self.fromVersion = message.fromVersion;
        self.mimeType = message.mimeType;
        self.plainData = message.plainData;
        self.dateTime = message.dateTime;
        self.errorStatus = message.errorStatus;
        self.formattedDate = message.formattedDate;
        self.dataSize = message.dataSize;
        self.resendId = message.resendId;
        self.loading = message.loading;
        self.loaded = message.loaded;
        self.rowPortraitHeight = message.rowPortraitHeight;
        self.rowLandscapeHeight = message.rowLandscapeHeight;
        self.shareable = message.shareable;
        self.hashed = message.hashed;
        self.voicePlayed = message.voicePlayed;
        self.playVoice = message.playVoice;
    }
    return self;
}


-(id) initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder: coder];
    if (self) {
        self.plainData = [coder decodeObjectForKey:@"plainData"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder{
    [super encodeWithCoder:encoder];
    if (!self.data) {
        [encoder encodeObject:self.plainData forKey:@"plainData"];
    }
}

@end
