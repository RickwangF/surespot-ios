//
//  GetPublicKeysOperation.h
//  surespot
//
//  Created by Adam on 10/20/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IdentityController.h"
#import "CredentialCachingController.h"

@interface GetKeyVersionOperation : NSOperation

-(id) initWithCache: (CredentialCachingController *) cache ourUsername: (NSString *) ourUsername theirUsername:(NSString *) theirUsername completionCallback: (CallbackStringBlock)  callback;
@end
