//
//  MessageDecryptionOperation.m
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "MessageDecryptionOperation.h"
#import "EncryptionController.h"
#import "UIUtils.h"
#import "NSBundle+FallbackLanguage.h"

@interface MessageDecryptionOperation()
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end

@implementation MessageDecryptionOperation
-(id) initWithMessage: (SurespotMessage *) message size: (CGSize) size completionCallback:(void(^)(SurespotMessage *))  callback {
    if (self = [super init]) {
        self.callback = callback;
        self.message = message;
        self.size = size;
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
    
}


-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    
    if ([_message.mimeType isEqualToString: MIME_TYPE_TEXT]) {
        
        if ([_message data]) {
            
            [EncryptionController symmetricDecryptString:[_message data] ourVersion:[_message getOurVersion] theirUsername:[_message getOtherUser] theirVersion:[_message getTheirVersion]  iv:[_message iv] hashed: [_message hashed] callback:^(NSString * plaintext){
                
                //figure out message height for both orientations
                if (![UIUtils stringIsNilOrEmpty:plaintext]){
                    _message.plainData = plaintext;
                }
                else {
                    //todo more granular error messages
                    _message.plainData = NSLocalizedString(@"message_error_decrypting_message",nil);
                }
                
                [UIUtils setTextMessageHeights:_message size:_size];
                [self finish];
                
            }];
            
            
        }
        else {
            [self finish];
        }
    }
    
    else {
        if ([_message.mimeType isEqualToString: MIME_TYPE_IMAGE]) {
            [UIUtils setImageMessageHeights:_message size:_size];
        }
        else {
            if ([_message.mimeType isEqualToString: MIME_TYPE_M4A]) {
                [UIUtils setVoiceMessageHeights:_message size:_size];
            }
        }
        [self finish];
    }
}

- (void)finish
{
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    self.callback(_message);
    self.callback = nil;
    self.message = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end

