//
//  SendVoiceMessageOperation.mm
//  surespot
//
//  Created by Adam on 4/26/17.
//  Copyright © 2017 surespot. All rights reserved.
//


#import <AssetsLibrary/AssetsLibrary.h>

#import "SendVoiceMessageOperation.h"
#import "CocoaLumberjack.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import "NetworkManager.h"
#import "UIUtils.h"
#import "SDWebImageManager.h"
#import "ChatDataSource.h"

#import "ChatManager.h"
#import "NSData+Base64.h"


#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface SendVoiceMessageOperation()
@property NSData * encryptedImageData;
@end

@implementation SendVoiceMessageOperation


-(void) prepAndSendMessage {
    //    if (!self.message.plainData) {
    //        //   DDLogDebug(@"prepAndSendMessage )
    //        [self finish:nil];
    //        return;
    //    }
    //
    if (![self.message readyToSend]) {
        
        NSString * ourLatestVersion = [[IdentityController sharedInstance] getOurLatestVersion: self.message.from];
        
        [[IdentityController sharedInstance] getTheirLatestVersionForOurUsername:self.message.from theirUsername: self.message.to callback:^(NSString *version) {
            if (version) {
                //encrypt and upload the voice data
                NSURL* url = [NSURL URLWithString: self.message.plainData];
                NSData * voiceData = [NSData dataWithContentsOfURL: url];
                [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
                
                
                //encrypt
                [EncryptionController symmetricEncryptData:voiceData
                                               ourUsername:self.message.from
                                                ourVersion:ourLatestVersion
                                             theirUsername:self.message.to
                                              theirVersion:version
                                                        iv:self.message.iv
                                                  callback:^(NSData * encryptedVoiceData) {
                                                      if (encryptedVoiceData) {
                                                          //create message
                                                          
                                                          self.message.fromVersion = ourLatestVersion;
                                                          self.message.toVersion = version;
                                                          
                                                          NSString * key = [@"dataKey_" stringByAppendingString: self.message.iv];
                                                          self.message.hashed = YES;
                                                          
                                                          DDLogInfo(@"adding local data to cache %@", key);
                                                          [[[SDWebImageManager sharedManager] imageCache] storeImage:voiceData imageData:encryptedVoiceData mimeType: self.message.mimeType forKey:key toDisk:YES async:NO];
                                                          
                                                          self.message.data = key;
                                                          
                                                          //add message locally before we upload it
                                                          ChatDataSource * cds = [[[ChatManager sharedInstance] getChatController: self.message.from] getDataSourceForFriendname:self.message.to];
                                                          [cds addMessage:self.message refresh:YES];
                                                          [self sendImageMessageViaHttp];
                                                
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
    }
    else {
        [self sendImageMessageViaHttp];
    }
}

-(void) sendImageMessageViaHttp {
    NSData * encryptedImageData = _encryptedImageData;
    
    if (!encryptedImageData) {
        encryptedImageData = [[[SDWebImageManager sharedManager] imageCache] dataForKey:self.message.data];
    }
    
    //    if (!encryptedImageData) {
    //        DDLogDebug(@"No encrypted image data, message: %@", self.message);
    //     //   self.message.data = nil;
    //      //  [self scheduleRetrySend];
    //        [self finish:nil];
    //        return;
    //    }
    //upload image to server
    DDLogInfo(@"uploading image %@ to server", self.message.data);
    [[[NetworkManager sharedInstance] getNetworkController:self.message.from]
     postFileStreamData:encryptedImageData
     ourVersion:self.message.fromVersion
     theirUsername:self.message.to
     theirVersion:self.message.toVersion
     fileid:self.message.iv
     mimeType:self.message.mimeType
     successBlock:^(id JSON) {
         
         //update the message with the id and url
         NSInteger serverid = [[JSON objectForKey:@"id"] integerValue];
         NSString * url = [JSON objectForKey:@"url"];
         NSInteger size = [[JSON objectForKey:@"size"] integerValue];
         NSDate * date = [NSDate dateWithTimeIntervalSince1970: [[JSON objectForKey:@"time"] doubleValue]/1000];
         
         DDLogInfo(@"uploaded data %@ to server successfully, server id: %ld, url: %@, date: %@, size: %ld", self.message.iv, (long)serverid, url, date, (long)size);
         
         SurespotMessage * updatedMessage = [self.message copyWithZone:nil];
         
         updatedMessage.serverid = serverid;
         updatedMessage.data = url;
         updatedMessage.dateTime = date;
         updatedMessage.dataSize = size;
         
         ChatDataSource * cds = [[[ChatManager sharedInstance] getChatController: self.message.from] getDataSourceForFriendname:self.message.to];
         
         [cds addMessage:updatedMessage refresh:YES];
         
         [self finish:updatedMessage];
     } failureBlock:^(NSURLResponse *operation, NSError *Error) {
         long statusCode = [(NSHTTPURLResponse *) operation statusCode];
         DDLogInfo(@"uploaded image %@ to server failed, statuscode: %ld", self.message.data, statusCode);
         
         [self scheduleRetrySend];
     }];
    
}



@end
