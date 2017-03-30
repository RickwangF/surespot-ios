//
//  GenerateSharedSecretOperation.m
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "GenerateSharedSecretOperation.h"
#import "EncryptionController.h"
#import "CocoaLumberjack.h"


#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface GenerateSharedSecretOperation()
@property (nonatomic, assign) ECDHPrivateKey* ourPrivateKey;
@property (nonatomic, assign) ECDHPublicKey* theirPublicKey;
@property (nonatomic, assign) BOOL hashed;
@end


@implementation GenerateSharedSecretOperation

-(id) initWithOurPrivateKey: (ECDHPrivateKey *) ourPrivateKey theirPublicKey: (ECDHPublicKey *) theirPublicKey hashed: (BOOL) hashed completionCallback:(void(^)(NSData *)) callback {
    if (self = [super init]) {
        self.callback = callback;
        self.ourPrivateKey = ourPrivateKey;
        self.theirPublicKey = theirPublicKey;
        self.hashed = hashed;
    }
    return self;
}

-(void) main {
    @autoreleasepool {
        
        //generate shared secret and store it in cache
        NSData * sharedSecret = [EncryptionController generateSharedSecret:_ourPrivateKey  publicKey:_theirPublicKey hashed:_hashed];
        self.callback(sharedSecret);
    }
}



@end
