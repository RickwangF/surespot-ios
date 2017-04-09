//
//  SurespotConstants.h
//  surespot
//
//  Created by Adam on 11/18/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^CallbackBlock) (id  result);
typedef void (^CallbackErrorBlock) (NSString * error, id  result);
typedef void (^CallbackStringBlock) (NSString * result);
typedef void (^CallbackDictionaryBlock) (NSDictionary * result);

@interface SurespotConstants : NSObject
extern BOOL const socketLog;
extern NSString * const serverPublicKeyString;

extern NSInteger const SAVE_MESSAGE_COUNT;
extern NSString * const MIME_TYPE_IMAGE;
extern NSString * const MIME_TYPE_TEXT;
extern NSString * const MIME_TYPE_M4A;
extern NSString * const MIME_TYPE_GIF_LINK;
extern NSString * const MIME_TYPE_FILE;
extern NSInteger const MAX_IDENTITIES;


@end
