//
//  ChatDataSource.m
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "ChatDataSource.h"
#import "NetworkManager.h"
#import "MessageDecryptionOperation.h"
#import "ChatUtils.h"
#import "IdentityController.h"
#import "FileController.h"
#import "CocoaLumberjack.h"
#import "UIUtils.h"
#import "SurespotConstants.h"
#import "SDWebImageManager.h"
#import "ChatManager.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface ChatDataSource()
@property (nonatomic, strong) NSOperationQueue * decryptionQueue;
@property (nonatomic, strong) NSString * ourUsername;
@property (nonatomic, strong) NSString * theirUsername;
@property (nonatomic, strong) NSMutableDictionary * controlMessages;
@property (atomic, assign) BOOL noEarlierMessages;
@property (atomic, assign) BOOL loadingEarlier;
@end

@implementation ChatDataSource

-(ChatDataSource*)initWithTheirUsername:(NSString *) theirUsername ourUsername: (NSString * ) ourUsername availableId:(NSInteger)availableId availableControlId:( NSInteger) availableControlId callback:(CallbackBlock) initCallback {
    
    // DDLogInfo(@"username: %@, ourUsername: %@, availableid: %ld, availableControlId: %ld", username, ourUsername, (long)availableId, (long)availableControlId);
    //call super init
    self = [super init];
    
    if (self != nil) {
        _decryptionQueue = [[NSOperationQueue alloc] init];
        [_decryptionQueue setUnderlyingQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        _ourUsername = ourUsername;
        _theirUsername = theirUsername;
        _messages = [NSMutableArray new];
        _controlMessages = [NSMutableDictionary new];
        
        NSArray * messages;
        
        NSString * path =[FileController getChatDataFilenameForSpot:[ChatUtils getSpotUserA:theirUsername userB:ourUsername] ourUsername: ourUsername];
        DDLogVerbose(@"looking for chat data at: %@", path);
        id chatData = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);
        
        dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            //   DDLogInfo(@"dispatch group 1 notified");
            //If the socket is connected get the data from the server, otherwise it'll be retrieved when the socket connects
            if ([[[ChatManager sharedInstance] getChatController: _ourUsername] isConnected] && (availableId > _latestMessageId || availableControlId > _latestControlMessageId)) {
                dispatch_group_t group2 = dispatch_group_create();
                //                   DDLogInfo(@"dispatch group enter %@", username);
                dispatch_group_enter(group2);
                dispatch_group_notify(group2, dispatch_get_main_queue(), ^{
                    DDLogInfo(@"stopProgress username: %@", _theirUsername);
                    NSDictionary* userInfo = @{@"key": theirUsername};
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"stopProgress" object:self userInfo:userInfo];
                    initCallback(nil);
                });
                
                
                //   DDLogDebug(@"getting messageData latestMessageId: %ld, latestControlId: %ld", (long)_latestMessageId ,(long)_latestControlMessageId);
                //load message data
                //   DDLogInfo(@"startProgress: %@", username);

                NSDictionary* userInfo = @{@"key": theirUsername};
                [[NSNotificationCenter defaultCenter] postNotificationName:@"startProgress" object:self userInfo:userInfo];
                [[[NetworkManager sharedInstance] getNetworkController:_ourUsername] getMessageDataForUsername:_theirUsername andMessageId:_latestMessageId andControlId:_latestControlMessageId successBlock:^(NSURLSessionTask *task, id JSON) {
                    //    DDLogInfo(@"get messageData response");
                    
                    NSArray * controlMessages =[((NSDictionary *) JSON) objectForKey:@"controlMessages"];
                    
                    [self handleControlMessages:controlMessages];
                    
                    NSArray * messages =[((NSDictionary *) JSON) objectForKey:@"messages"];
                    
                    for (id jsonMessage in messages) {
                        SurespotMessage *lastMessage = [[SurespotMessage alloc] initWithDictionary:jsonMessage];
                        //    DDLogInfo(@"dispatch group message enter %@", username);
                        dispatch_group_enter(group2);
                        [self addMessage:lastMessage refresh:NO callback:^(id result) {
                            //      DDLogInfo(@"message decrypted %@, iv: %@", username, lastMessage.iv);
                            //      DDLogInfo(@"dispatch group mesasge leave %@", username);
                            dispatch_group_leave(group2);
                        }];
                    }
                    
                    // DDLogInfo(@"dispatch group leave %@", username);
                    dispatch_group_leave(group2);
                    
                } failureBlock:^(NSURLSessionTask *operation, NSError *Error) {
                    DDLogInfo(@"get messagedata response error: %@",  Error);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [UIUtils showToastKey:@"loading_latest_messages_failed"];
                    });
                    
                    dispatch_group_leave(group2);
                }];
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    initCallback(nil);
                });
            }
            
        });
        
        
        if (chatData) {
            DDLogInfo(@"loading chat data from: %@", path);
            
            _latestControlMessageId = [[chatData objectForKey:@"latestControlMessageId"] integerValue];
            messages = [chatData objectForKey:@"messages"];
        
            //convert messages to SurespotMessage
            for (SurespotMessage * message in messages) {
                DDLogVerbose(@"adding message %@, iv: %@", message, message.iv);
                dispatch_group_enter(group);
                [self addMessage:message refresh:NO callback:^(id result) {
                    //     DDLogInfo(@"message decrypted %@, iv: %@", weakSelf.username, message.iv);
                    dispatch_group_leave(group);
                }];
            }
            
            dispatch_group_leave(group);
        }
        else {
            dispatch_group_leave(group);
        }
        
        DDLogVerbose( @"latestMEssageid: %ld, latestControlId: %ld", (long)_latestMessageId ,(long)_latestControlMessageId);
    }
    
    
    DDLogVerbose(@"init complete");
    return self;
}

-(BOOL) addMessage:(SurespotMessage *) message refresh:(BOOL) refresh {
    return [self addMessage:message refresh:refresh callback:nil];
}

-(BOOL) addMessage:(SurespotMessage *)message  refresh: (BOOL) refresh callback: (CallbackBlock) callback {
    BOOL isNew = NO;
    @synchronized (_messages)  {
        NSMutableArray * applicableControlMessages  = nil;
        if (message.serverid > 0 && ![UIUtils stringIsNilOrEmpty:message.plainData]) {
            
            // see if we have applicable control messages and apply them if necessary
            NSArray * controlMessages = [_controlMessages allValues];
            applicableControlMessages = [NSMutableArray new];
            
            for (SurespotControlMessage * cm in controlMessages) {
                NSInteger messageId = [cm.moreData  integerValue];
                if (message.serverid == messageId) {
                    //if we're going to delete the message don't bother adding it
                    if ([cm.action isEqualToString:@"delete"] ) {
                        DDLogVerbose(@"message going to be deleted, marking message as old");
                        isNew = NO;
                    }
                    [applicableControlMessages addObject:cm];
                }
            }
        }
        
        DDLogVerbose(@"looking for message iv: %@", message.iv);
        NSUInteger index = [self.messages indexOfObject:message];
        if (index == NSNotFound) {
            [self.messages addObject:message];
            if (!message.plainData) {
                BOOL blockRefresh = refresh;
                refresh = false;
                CGSize size = [UIScreen mainScreen ].bounds.size;
                
                DDLogVerbose(@"added %@,  now decrypting message iv: %@, width: %f, height: %f",message, message.iv, size.width, size.height);
                
                MessageDecryptionOperation * op = [[MessageDecryptionOperation alloc]
                                                   initWithMessage:message
                                                   size: size
                                                   ourUsername:_ourUsername
                                                   completionCallback:^(SurespotMessage  * message){
                                                       if (blockRefresh) {
                                                           if ([_decryptionQueue operationCount] == 0) {
                                                               [self postRefresh];
                                                           }
                                                       }
                                                       
                                                       if (callback) {
                                                           callback(nil);
                                                       }
                                                   }];
                [_decryptionQueue addOperation:op];
            }
            else {
                DDLogVerbose(@"added message already decrypted iv: %@", message.iv);
                
                if (callback) {
                    callback(nil);
                }
            }
            
            if (![ChatUtils isOurMessage:message ourUsername:_ourUsername]) {
                DDLogVerbose(@"not our message, marking message as new");
                isNew = YES;
            }
            else {
                isNew = NO;
            }
        }
        else {
            if (callback) {
                callback(nil);
            }
            DDLogInfo(@"updating message: %@", message);
            SurespotMessage * existingMessage = [self.messages objectAtIndex:index];
            DDLogInfo(@"updating existing message: %@", message);
            if (message.serverid > 0) {
                existingMessage.serverid = message.serverid;
                if (message.dateTime) {
                    existingMessage.dateTime = message.dateTime;
                }
                existingMessage.errorStatus = 0;
                if (message.dataSize > 0) {
                    existingMessage.dataSize = message.dataSize;
                }
                
                
                
                if (![existingMessage.data isEqualToString:message.data]) {
                    //update cache to avoid downloading image we just sent and save on web traffic
                    if ([existingMessage.data hasPrefix:@"dataKey_"]) {
                        
                        //get cached image datas
                        id data = [[[SDWebImageManager sharedManager] imageCache] imageFromMemoryCacheForKey:existingMessage.data];
                        NSData * encryptedImageData = [[[SDWebImageManager sharedManager] imageCache] diskImageDataBySearchingAllPathsForKey:existingMessage.data];
                        
                        if (data && encryptedImageData) {
                            //save data for new remote key
                            [[[SDWebImageManager sharedManager] imageCache] storeImage:data imageData:encryptedImageData mimeType: message.mimeType forKey:message.data toDisk:YES];
                            
                            //remove now defunct cached local data
                            [[[SDWebImageManager sharedManager] imageCache] removeImageForKey:existingMessage.data fromDisk:YES];
                            
                            DDLogInfo(@"key exists for %@: %@", existingMessage.data, [[[SDWebImageManager sharedManager] imageCache] diskImageExistsWithKey:existingMessage.data] ? @"YES" : @"NO" );
                        }
                    }
                    
                    existingMessage.data = message.data;
                }
            }
            
            if (message.plainData && !existingMessage.plainData) {
                
                existingMessage.plainData = message.plainData;
            }
            
            
            if (message.data && !existingMessage.data) {
                existingMessage.data = message.data;
            }

            
            if (message.toVersion && !existingMessage.toVersion) {
                existingMessage.toVersion = message.toVersion;
            }

            
            if (message.fromVersion && !existingMessage.fromVersion) {
                existingMessage.fromVersion = message.fromVersion;
            }

            
            if (message.errorStatus && !existingMessage.errorStatus) {
                existingMessage.errorStatus = message.errorStatus;
            }
            DDLogInfo(@"updating result message: %@", existingMessage);

        }
        
        if (applicableControlMessages && [applicableControlMessages count] > 0) {
            DDLogVerbose(@"retroactively applying control messages to message id %ld", (long)message.serverid);
            for (SurespotControlMessage * cm in applicableControlMessages) {
                [self handleControlMessage:cm];
            }
        }
        
        
    }
    
    if (message.serverid > _latestMessageId) {
        DDLogVerbose(@"updating latest message id: %ld", (long)message.serverid);
        _latestMessageId = message.serverid;
    }
    else {
        DDLogVerbose(@"have received before, marking message as old");
        isNew = NO;
    }
    
    if (message.serverid == 1) {
        _noEarlierMessages = YES;
    }
    
    
    
    if (refresh) {
        if ([_decryptionQueue operationCount] == 0) {
            [self postRefresh];
        }
    }
    
    DDLogVerbose(@"isNew: %hhd", (char)isNew);
    
    return isNew;
    
    
}


-(void) postRefresh {
    [self postRefreshScroll:YES];
}

-(void) postRefreshScroll: (BOOL) scroll {
    DDLogInfo(@"postRefreshScroll username: %@, %hhd", _theirUsername, (char)scroll);
    [self sort];
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshMessages"
                                                            object:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                    _theirUsername, @"username",
                                                                    [NSNumber numberWithBool:scroll],  @"scroll",
                                                                    nil] ];
    });
}

-(void) writeToDisk {
    
    
    NSString * spot = [ChatUtils getSpotUserA:_ourUsername userB:_theirUsername];
    NSString * filename =[FileController getChatDataFilenameForSpot: spot ourUsername:_ourUsername];
    DDLogInfo(@"saving chat data to disk,filename: %@, spot: %@", filename, spot);
    NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
    
    [self sort];
    
    @synchronized (_messages)  {
        //only save x messages
        NSInteger count = _messages.count < SAVE_MESSAGE_COUNT ? _messages.count : SAVE_MESSAGE_COUNT;
        
        NSArray * messages = [_messages subarrayWithRange:NSMakeRange([_messages count] - count ,count)];
        [dict setObject:messages forKey:@"messages"];
        [dict setObject:[NSNumber numberWithInteger:_latestControlMessageId] forKey:@"latestControlMessageId"];
        BOOL saved =[NSKeyedArchiver archiveRootObject:dict toFile:filename];
        
        DDLogInfo(@"saved %lu messages for user %@, success?: %@",(unsigned long)[messages count],_theirUsername, saved ? @"YES" : @"NO");
    }
    
}

-(void) deleteMessage: (SurespotMessage *) message initiatedByMe: (BOOL) initiatedByMe {
    BOOL myMessage = [[message from] isEqualToString:_ourUsername];
    if (initiatedByMe || !myMessage) {
        [self deleteMessageById: message.serverid];
    }
}

-(SurespotMessage *) getMessageById: (NSInteger) serverId {
    @synchronized (_messages) {
        __block SurespotMessage * message;
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid]  == serverId) {
                message = obj;
                *stop = YES;
            }
        }];
        return message;
    }
}

-(SurespotMessage *) getMessageByIv: (NSString *) iv {
    @synchronized (_messages) {
        __block SurespotMessage * message;
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([[obj iv]  isEqualToString: iv]) {
                message = obj;
                *stop = YES;
            }
        }];
        return message;
    }
}

-(void) deleteMessageById: (NSInteger) serverId {
    DDLogVerbose(@"serverID: %ld", (long)serverId);
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid] == serverId) {
                [_messages removeObjectAtIndex:idx];
                [self postRefreshScroll:NO];
                *stop = YES;
            }
        }];
    }
}

-(void) deleteMessageByIv: (NSString *) iv {
    DDLogVerbose(@"iv: %@", iv);
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([[obj iv] isEqualToString:iv]) {
                [_messages removeObjectAtIndex:idx];
                [self postRefresh];
                *stop = YES;
            }
        }];
    }
}


-(BOOL) handleMessages: (NSArray *) messages {
    __weak ChatDataSource* weakSelf =self;
    SurespotMessage * lastMessage;
    BOOL areNew = NO;
    for (id jsonMessage in messages) {
        lastMessage = [[SurespotMessage alloc] initWithDictionary:jsonMessage];
        BOOL isNew = [self addMessage:lastMessage refresh:NO callback:^(id result) {
            if ([weakSelf.decryptionQueue operationCount] == 0) {
                [weakSelf postRefresh];
            }
        }];
        if (isNew  ) {
            areNew = isNew;
        }
    }
    
    return areNew;
}

-(void) handleEarlierMessages: (NSArray *) messages  callback: (CallbackBlock) callback{
    __block NSInteger count = [messages count];
    if (count == 0) {
        callback([NSNumber numberWithLong:0]);
        _noEarlierMessages = YES;
        return;
    }
    __weak ChatDataSource* weakSelf =self;
    
    SurespotMessage * lastMessage;
    for (id jsonMessage in messages) {
        lastMessage = [[SurespotMessage alloc] initWithDictionary:jsonMessage];
        DDLogInfo(@"adding earlier message, id: %ld", (long)lastMessage.serverid);
        [self addMessage:lastMessage refresh:NO callback:^(id result) {
            if (--count == 0) {
                [weakSelf sort];
                DDLogInfo(@"all messages added, calling back");
                dispatch_async(dispatch_get_main_queue(), ^{
                    callback([NSNumber numberWithLong:[messages count]]);
                });
            }
        }];
    }    
}


-(void) handleControlMessages: (NSArray *) controlMessages {
    
    SurespotControlMessage * message;
    
    for (id jsonMessage in controlMessages) {
        
        
        message = [[SurespotControlMessage alloc] initWithDictionary: jsonMessage];
        [self handleControlMessage:message];
        
    }
    
}

-(void) handleControlMessage: (SurespotControlMessage *) message {
    if ([message.type isEqualToString:@"message"]) {
        
        DDLogVerbose(@"action: %@, id: %ld", message.action, (long)message.controlId );
        
        if  (message.controlId >  self.latestControlMessageId) {
            self.latestControlMessageId = message.controlId;
        }
        BOOL controlFromMe = [[message from] isEqualToString:_ourUsername];
        
        if ([[message action] isEqualToString:@"delete"]) {
            NSInteger messageId = [[message moreData] integerValue];
            SurespotMessage * dMessage = [self getMessageById: messageId];
            
            if (dMessage) {
                [self deleteMessage:dMessage initiatedByMe:controlFromMe];
            }
        }
        else {
            if ([[message action] isEqualToString:@"deleteAll"]) {
                if (message.moreData) {
                    if (controlFromMe) {
                        [self deleteAllMessagesUTAI:[ message.moreData integerValue] ];
                    }
                    else {
                        [self deleteTheirMessagesUTAI:[ message.moreData integerValue] ];
                    }
                }
            }
            else {
                if ([[message action] isEqualToString:@"shareable"] || [[message action] isEqualToString:@"notshareable"]) {
                    NSInteger messageId = [[message moreData] integerValue];
                    SurespotMessage * dMessage = [self getMessageById: messageId];
                    
                    if (dMessage) {
                        [dMessage setShareable:[message.action isEqualToString:@"shareable"] ? YES : NO];
                        [self postRefreshScroll:NO];
                    }
                }
            }
        }
    }
    
    @synchronized (_controlMessages) {
        [_controlMessages setObject:message forKey:[NSNumber numberWithInteger: message.controlId  ]];
    }
}

-(void) deleteAllMessagesUTAI: (NSInteger) messageId {
    DDLogVerbose(@"UTAI messageID: %ld", (long)messageId);
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid] <= messageId) {
                DDLogVerbose(@"deleting messageID: %ld", (long)[obj serverid]);
                [_messages removeObjectAtIndex:idx];
            }
        }];
    }
    
    [self writeToDisk];
    [self postRefresh];
}

-(void) deleteTheirMessagesUTAI: (NSInteger) messageId {
    
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SurespotMessage * obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid] <= messageId && ![[obj from] isEqualToString:_ourUsername]) {
                DDLogVerbose(@"deleting messageID: %ld", (long)[obj serverid]);
                [_messages removeObjectAtIndex:idx];
            }
        }];
    }
    
    [self writeToDisk];
    [self postRefresh];
}

-(void) userDeleted {
    
    [self deleteTheirMessagesUTAI:NSIntegerMax];
}

-(void) sort {
    @synchronized (_messages) {
        DDLogVerbose(@"sorting messages for %@", _theirUsername);
        NSArray *sortedArray;
        sortedArray = [_messages sortedArrayUsingComparator:^NSComparisonResult(SurespotMessage * a, SurespotMessage * b) {
            // DDLogVerbose(@"comparing a serverid: %ld, b serverId: %ld", (long)a.serverid, (long)b.serverid);
            if (a.serverid == b.serverid) {return NSOrderedSame;}
            if (a.serverid == 0) {return NSOrderedDescending;}
            if (b.serverid == 0) {return NSOrderedAscending;}
            if (a.serverid < b.serverid) return NSOrderedAscending;
            if (b.serverid < a.serverid) return NSOrderedDescending;
            //  DDLogVerbose(@"returning same");
            return NSOrderedSame;
            
        }];
        if (sortedArray) {
            _messages = [NSMutableArray arrayWithArray: sortedArray];
        }
    }
}

-(NSInteger) earliestMessageId {
    NSInteger earliestMessageId = NSIntegerMax;
    @synchronized (_messages) {
        for (int i=0;i<_messages.count;i++) {
            NSInteger serverId = [[_messages objectAtIndex:i] serverid];
            if (serverId > 0) {
                earliestMessageId = serverId;
                break;
            }
        }
    }
    return earliestMessageId;
}

-(void) loadEarlierMessagesCallback: (CallbackBlock) callback {
    
    if (_noEarlierMessages) {
        callback([NSNumber numberWithInteger:0]);
        return;
    }
    
    if (!_loadingEarlier) {
        _loadingEarlier = YES;
        
        NSInteger earliestMessageId = [self earliestMessageId];
        if (earliestMessageId == 1) {
            _noEarlierMessages = YES;
            callback([NSNumber numberWithInteger:0]);
            _loadingEarlier = NO;
            return;
        }
        
        if (earliestMessageId == NSIntegerMax ) {
            callback([NSNumber numberWithInteger:NSIntegerMax]);
            _loadingEarlier = NO;
            return;
        }
        
        [[[NetworkManager sharedInstance] getNetworkController:_ourUsername] getEarlierMessagesForUsername:_theirUsername messageId:earliestMessageId successBlock:^(NSURLSessionTask *task, id JSON) {
            
            NSArray * messages = JSON;
            if (messages.count == 0) {
                _noEarlierMessages = YES;
            }
            
            [self handleEarlierMessages:messages callback:callback];
            _loadingEarlier = NO;
        } failureBlock:^(NSURLSessionTask *operation, NSError *Error) {
            callback(nil);
            _loadingEarlier = NO;
            [UIUtils showToastKey:@"loading_earlier_messages_failed"];
        }];
    }
}
-(void) setMessageId: (NSInteger) serverid shareable: (BOOL) shareable {
    SurespotMessage * message = [self getMessageById:serverid];
    if (message) {
        message.shareable = shareable;
        [self postRefreshScroll:NO];
    }
}

@end
