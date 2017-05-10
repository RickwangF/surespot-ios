//
//  SendTextMessageOperation.mm
//  surespot
//
//  Created by Adam on 4/26/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import "SendTextMessageOperation.h"
#import "CocoaLumberjack.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import "NetworkManager.h"
#import "UIUtils.h"
#import "ChatManager.h"


#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@implementation SendTextMessageOperation

-(void) prepAndSendMessage {
    if (![self.message readyToSend]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString * ourLatestVersion = [[IdentityController sharedInstance] getOurLatestVersion: self.message.from];
            
            [[IdentityController sharedInstance] getTheirLatestVersionForOurUsername: self.message.from theirUsername: [self.message to] callback:^(NSString * version) {
                if (version) {
                    [self encryptMessage:self.message ourVersion:ourLatestVersion theirVersion:version callback:^(NSString * cipherText) {
                        if (cipherText) {
                            self.message.fromVersion = ourLatestVersion;
                            self.message.toVersion = version;
                            self.message.data = cipherText;
                            
                            ChatDataSource * cds = [[[ChatManager sharedInstance] getChatController: self.message.from] getDataSourceForFriendname:self.message.to];
                            [cds addMessage:self.message refresh:YES];

                            [self sendTextMessageViaHttp];
                        }
                        else {
                            [self scheduleRetrySend];
                        }
                    }];
                }
                else {
                    [self scheduleRetrySend];
                }
            }];
        });
    }
    else {
        [self sendTextMessageViaHttp];
    }
    
}

-(void) encryptMessage: (SurespotMessage *) message
            ourVersion: (NSString *) ourVersion
          theirVersion: (NSString *) theirVersion
              callback: (CallbackBlock) callback {
    [EncryptionController symmetricEncryptString: [message plainData]
                                     ourUsername: self.message.from
                                      ourVersion:ourVersion
                                   theirUsername:[message to]
                                    theirVersion:theirVersion
                                              iv:[message iv]
                                        callback:callback];
}

-(void) sendTextMessageViaHttp {
    NSMutableArray * messagesJson = [[NSMutableArray alloc] init];
    
    
    [messagesJson addObject:[self.message toNSDictionary]];
    
    
    [[[NetworkManager sharedInstance] getNetworkController:self.message.from]
     sendMessages:messagesJson
     
     successBlock:^(NSURLSessionTask *task, id JSON) {
         DDLogDebug(@"success sending message via http");
         //iterate through response statuses and handle accordingly
         NSArray * responses = [JSON objectForKey:@"messageStatus"];
         [responses enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary * _Nonnull messageStatus, NSUInteger idx, BOOL * _Nonnull stop) {
             NSInteger status = [[messageStatus objectForKey:@"status"] integerValue];
             dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                 
                 if (status == 204) {
                     SurespotMessage * message = [[SurespotMessage alloc] initWithDictionary:[messageStatus objectForKey:@"message"]];
                     ChatDataSource * cds = [[[ChatManager sharedInstance] getChatController: self.message.from] getDataSourceForFriendname:self.message.to];
                     [cds addMessage:message refresh:YES];
                     [self finish:message];
                 }
                 else {
                     [self finish:self.message];
                 }
             });
         }];
     }
     
     failureBlock:^(NSURLSessionTask *task, NSError *Error) {
         long statusCode = [(NSHTTPURLResponse *) task.response statusCode];
         DDLogInfo(@"sending text %@ to server failed, statuscode: %ld", self.message.data, statusCode);
         
         if (statusCode == 401) {
             [self finish:nil];
         }
         else {
             [self scheduleRetrySend];
         }
     }];    
}
@end
