//
//  ChatController.m
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "ChatController.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import "NSData+Base64.h"
#import "SurespotControlMessage.h"
#import "NetworkManager.h"
#import "ChatUtils.h"
#import "CocoaLumberjack.h"
#import "UIUtils.h"
#import "SurespotConstants.h"
#import "FileController.h"
#import "CredentialCachingController.h"
#import "SurespotErrorMessage.h"
#import "AFNetworkReachabilityManager.h"
#import "SDWebImageManager.h"
#import "SoundController.h"
#import "NSBundle+FallbackLanguage.h"
#import "SocketIO-Swift.h"
#import "SurespotConfiguration.h"
#import "SendVoiceMessageOperation.h"
#import "SendImageMessageOperation.h"
#import "SendTextMessageOperation.h"
#import "SurespotQueueMessage.h"
#import <UserNotifications/UserNotifications.h>
#import "SharedUtils.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

static const int MAX_REAUTH_RETRIES = 1;


@interface ChatController()
@property (strong, atomic) NSString * username;
@property (strong, atomic) NSMutableDictionary * chatDataSources;
@property (strong, atomic) HomeDataSource * homeDataSource;
@property (assign, atomic) NSInteger connectionRetries;
@property (strong, atomic) NSTimer * reconnectTimer;
@property (strong, nonatomic) NSMutableArray * messageBuffer;
@property (strong, nonatomic) SocketManager * socket;
@property (assign, atomic) BOOL reauthing;
@property (strong, atomic) NSOperationQueue * messageSendQueue;
@property (assign, atomic) UIBackgroundTaskIdentifier bgSocketTaskId;
@end

@implementation ChatController


-(ChatController*)init: (NSString *) username
{
    //call super init
    self = [super init];
    if (self != nil) {
        _username = username;
        _bgSocketTaskId = UIBackgroundTaskInvalid;
        _chatDataSources = [NSMutableDictionary new];
        _messageBuffer = [NSMutableArray new];
        
        //serial message queue to maintain order
        _messageSendQueue = [[NSOperationQueue alloc] init];
        [_messageSendQueue setMaxConcurrentOperationCount:1];
        [_messageSendQueue setUnderlyingQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    }
    
    return self;
}

-(void) addHandlers {
    DDLogDebug(@"adding handlers");
    //    [self.socket onAny:^(SocketAnyEvent * event) {
    //        DDLogInfo(@"socket event: %@, with items: %@",event.event, event.items);
    //    }];
    
    [self.socket.defaultSocket on:@"connect" callback:^(NSArray * data, SocketAckEmitter * ack) {
        DDLogInfo(@"socket connect");
        _reauthing = NO;
        _connectionRetries = 0;
        if (_reconnectTimer) {
            [_reconnectTimer invalidate];
        }
        
        [self processNextMessage];
        [self getData];
    }];
    
    [self.socket.defaultSocket on:@"disconnect" callback:^(NSArray * data, SocketAckEmitter * ack) {
        DDLogInfo(@"socket disconnect, data: %@", data);
        [[UIApplication sharedApplication] endBackgroundTask:_bgSocketTaskId];
        //server disconnect seems to yield data of "Socket Disconnected" vs client with "Disconnect" so only attempt reconnect when server disconnects
        id object0 = [data objectAtIndex:0];
        if ([object0 isEqualToString:@"Socket Disconnected"]) {
            DDLogInfo(@"Socket Disconnected (server)");
            [self reconnect];
        }
    }];
    
    [self.socket.defaultSocket on:@"error" callback:^(NSArray * data, SocketAckEmitter * ack) {
        DDLogInfo(@"socket error");
        
        BOOL reAuthing = NO;
        
        //handle not authorized
        id object0 = [data objectAtIndex:0];
        if ([object0 isEqualToString:@"not authorized"]) {
            
            DDLogInfo(@"socket not authorized");
            
            //if we're in reauth cycle and we've hit maximum reauth retries, bail
            if (_reauthing && (_connectionRetries > MAX_REAUTH_RETRIES)) {
                [[[NetworkManager sharedInstance] getNetworkController:_username] setUnauthorized];
                _reauthing = NO;
                _connectionRetries = 0;
                return;
            }
            
            //login again then try reconnecting
            reAuthing = [[[NetworkManager sharedInstance] getNetworkController:_username] reloginSuccessBlock:^(NSURLSessionTask *task, id JSON) {
                DDLogInfo(@"relogin success");
                _reauthing = YES;
                [self reconnect];
                
            } failureBlock:^(NSURLSessionTask *operation, NSError *Error) {
                _reauthing = YES;
                [self reconnect];
            }];
            
            if (!reAuthing) {
                DDLogInfo(@"not attempting to reauth");
                //stop the queue
                [_messageSendQueue cancelAllOperations];
                
                [[[NetworkManager sharedInstance] getNetworkController:_username] setUnauthorized];
                return;
            }
            
            return;
        }
        
        if ([self paused]) return;
        if (reAuthing) return;
        [self reconnect];
        
    }];
    
    [self.socket.defaultSocket on:@"message" callback:^(NSArray * data, SocketAckEmitter * ack) {
        DDLogDebug(@"socket message");
        NSDictionary * jsonMessage = [data objectAtIndex:0];
        SurespotMessage * message = [[SurespotMessage alloc] initWithDictionary:jsonMessage];
        
        //mark voice message to play automatically if tab is open
        if (![ChatUtils isOurMessage: message ourUsername:_username] && [message.mimeType isEqualToString:MIME_TYPE_M4A] && [[message getOtherUser: _username] isEqualToString:[self getCurrentChat]]) {
            message.playVoice = YES;
        }
        
        [self handleMessage:message];
        [self removeMessageFromBuffer:message];
        [self processNextMessage];
    }];
    
    [self.socket.defaultSocket on:@"control" callback:^(NSArray * data, SocketAckEmitter * ack) {
        NSDictionary * jsonControlMessage = [data objectAtIndex:0];
        SurespotControlMessage * message = [[SurespotControlMessage alloc] initWithDictionary:jsonControlMessage];
        [self handleControlMessage: message];
        [self processNextMessage];
    }];
    
    [self.socket.defaultSocket on:@"messageError" callback:^(NSArray * data, SocketAckEmitter * ack) {
        SurespotErrorMessage * message = [[SurespotErrorMessage alloc] initWithDictionary:[data objectAtIndex:0]];
        [self handleErrorMessage:message];
        [self processNextMessage];
    }];
}

-(void) disconnect {
    if (_socket) {
        DDLogDebug(@"disconnecting socket");
        [_socket disconnect ];
    }
}

-(void) pause {
    DDLogVerbose(@"chatcontroller pause");
    _paused = YES;
    [self shutdown];
    //  [self sendMessagesViaHttp];
}

-(void) shutdown {
    DDLogVerbose(@"chatcontroller shutdown");
    
    //give socket time to disconnect from server
    _bgSocketTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        _bgSocketTaskId = UIBackgroundTaskInvalid;
    }];
    DDLogVerbose(@"chatcontroller begin bg socket task: %lu", (unsigned long)_bgSocketTaskId);
    
    [self disconnect];
    [self saveState];
    
    if (_reconnectTimer) {
        [_reconnectTimer invalidate];
        _connectionRetries = 0;
    }
    _reauthing = NO;
    
}

-(void) reachabilityConnect {
    
    //tell operation on head of queue we connected in case it's awaiting timer firing to attempt sending
    if (_messageSendQueue.operationCount > 0) {
        SendMessageOperation * smo = _messageSendQueue.operations[0];
        [smo connected];
    }
}

-(void) connect {
    DDLogDebug(@"connecting socket");
    
    [self startProgress: @"socket"];
    NSHTTPCookie * cookie = [[CredentialCachingController sharedInstance] getCookieForUsername: _username];
    NSMutableDictionary * opts = [[NSMutableDictionary alloc] init];
    
    if (cookie) {
        [opts setObject:@[cookie] forKey:@"cookies"];
    }
    
    [opts setObject:[NSNumber numberWithBool:YES] forKey:@"forceWebsockets"];
    [opts setObject:[NSNumber numberWithBool:socketLog] forKey:@"log"];
    [opts setObject:[NSNumber numberWithBool:NO] forKey:@"reconnects"];
    [opts setObject:[NSNumber numberWithBool:YES] forKey:@"compress"];
    
    //#ifdef DEBUG
    //       [opts setObject:[NSNumber numberWithBool:YES] forKey:@"selfSigned"];
    //#endif
    
    if (self.socket) {
        DDLogDebug(@"removing all handlers");
        
        [self.socket.defaultSocket removeAllHandlers];
        [self.socket disconnect];
    }
    
    DDLogDebug(@"initing new socket");
    SocketManager* manager = [[SocketManager alloc] initWithSocketURL:[NSURL URLWithString:[[SurespotConfiguration sharedInstance] baseUrl]] config: opts];
    self.socket = manager;
    [self addHandlers];
    [self.socket.defaultSocket connect];
}

-(BOOL) isConnected {
    return [self.socket status] == SocketIOStatusConnected;
}

-(void) resume {
    DDLogVerbose(@"chatcontroller resume");
    _paused = NO;
    [self loadMessageQueue];
    [self connect];
}

-(void) reconnect {
    //start reconnect cycle
    if (_reconnectTimer) {
        [_reconnectTimer invalidate];
    }
    
    if (++_connectionRetries <= RETRY_ATTEMPTS) {
        
        
        //exponential random backoff
        double timerInterval = [UIUtils generateIntervalK: _connectionRetries maxInterval: RETRY_DELAY];
        DDLogDebug(@ "attempting reconnect in: %f" , timerInterval);
        _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(reconnectTimerFired:) userInfo:nil repeats:NO];
    }
    else {
        DDLogDebug(@"reconnect retries %ld exhausted, giving up", (long)_connectionRetries);
    }
}

-(void) reconnectTimerFired: (NSTimer *) timer {
    [self connect];
}

- (ChatDataSource *) createDataSourceForFriendname: (NSString *) friendname availableId:(NSInteger)availableId availableControlId: (NSInteger) availableControlId callback:(CallbackBlock) createCallback {
    @synchronized (_chatDataSources) {
        ChatDataSource * dataSource = [self.chatDataSources objectForKey:friendname];
        if (dataSource == nil) {
            dataSource = [[ChatDataSource alloc] initWithTheirUsername:friendname ourUsername:_username availableId: availableId availableControlId:availableControlId callback: createCallback] ;
            
            Friend  * afriend = [_homeDataSource getFriendByName:friendname];
            if (afriend && [afriend isDeleted]) {
                [dataSource userDeleted];
            }
            
            [self.chatDataSources setObject: dataSource forKey: friendname];
        }
        else {
            createCallback(nil);
        }
        return dataSource;
    }
}

- (ChatDataSource *) getDataSourceForFriendname: (NSString *) friendname {
    @synchronized (_chatDataSources) {
        return [self.chatDataSources objectForKey:friendname];
    }
}

-(void) destroyDataSourceForFriendname: (NSString *) friendname {
    @synchronized (_chatDataSources) {
        id cds = [_chatDataSources objectForKey:friendname];
        
        if (cds) {
            [cds writeToDisk];
            [_chatDataSources removeObjectForKey:friendname];
        }
    }
}


-(void) getData {
    //  [self startProgress];
    
    //if we have no friends and have never received a user control message
    //load friends and latest ids
    if ([_homeDataSource.friends count] ==0 && _homeDataSource.latestUserControlId == 0) {
        
        [_homeDataSource loadFriendsCallback:^(BOOL success) {
            if (success) {
                //not gonna be much data if we don't have any friends
                if ([_homeDataSource.friends count] > 0 || _homeDataSource.latestUserControlId > 0) {
                    //in this case assume we don't have any new messages
                    [self getLatestData: YES];
                }
                else {
                    [self handleAutoinvites];
                    [self stopProgress: @"socket"];
                }
            }
            else {
                [self stopProgress: @"socket"];
            }
            
        }];
    }
    else {
        [self getLatestData: NO];
    }
    
}

-(void) saveState {
    if (_homeDataSource) {
        [_homeDataSource writeToDisk];
    }
    
    //save message queue
    [self saveMessageQueue];
    
    if (_chatDataSources) {
        @synchronized (_chatDataSources) {
            for (id key in _chatDataSources) {
                [[_chatDataSources objectForKey:key] writeToDisk];
            }
        }
    }
    
    //move messages from send queue to resend queue
    //l [_resendBuffer addObjectsFromArray:_sendBuffer];
    // [_sendBuffer removeAllObjects];
}

-(void) saveMessageQueue {
    NSString * pw = [[IdentityController sharedInstance] getStoredPasswordForIdentity:_username];
    if (pw) {
        NSString * filePath = [FileController getMessageQueueFilename: _username];
        DDLogDebug(@"saving message queue at: %@", filePath);
        
        NSMutableArray * saveBuffer = [[NSMutableArray alloc] init];
        
        [_messageBuffer enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            {
                SurespotQueueMessage * qm = [[SurespotQueueMessage alloc] initFromMessage:obj];
                DDLogDebug(@"Saving message: %@", qm);
                [saveBuffer addObject:qm];
            }
        }];
        
        
        NSData * queueData = [NSKeyedArchiver archivedDataWithRootObject:saveBuffer];
        
        //save unsent messages encrypted as the plain text may not have been encrypted for sending yet
        NSData * encryptedQueue = [EncryptionController encryptData:queueData withPassword: pw];
        [encryptedQueue writeToFile:filePath atomically:TRUE];
    }
}

-(void) loadMessageQueue {
    NSString * filePath = [FileController getMessageQueueFilename: _username];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    if (data) {
        
        //NSError* error = nil;
        NSData * queuedMessageData = [EncryptionController decryptData: data withPassword:[[IdentityController sharedInstance] getStoredPasswordForIdentity:_username]];
        if (queuedMessageData) {
            NSArray * queuedMessages = [NSKeyedUnarchiver unarchiveObjectWithData:queuedMessageData];
            @synchronized(_messageBuffer) {
                [queuedMessages enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    {
                        SurespotQueueMessage * qm = [[SurespotQueueMessage alloc] initFromMessage:obj];
                        SurespotMessage * sm = [qm copyWithZone:nil];
                        
                        DDLogDebug(@"loadMessageQueue adding message: %@", sm);
                        
                        NSString * friendname = [sm getOtherUser:_username];
                        ChatDataSource * dataSource = [self getDataSourceForFriendname: friendname];
                        [dataSource addMessage: sm refresh:NO];
                        [dataSource postRefresh];
                        
                        [self enqueueMessage:sm];
                    }
                }];
            }
        }
    }
}

-(void) getLatestData: (BOOL) suppressNew {
    DDLogVerbose(@"getLatestData, chatDatasources count: %lu", (unsigned long)[_chatDataSources count]);
    
    NSMutableArray * messageIds = [[NSMutableArray alloc] init];
    
    //build message id list for open chats
    @synchronized (_chatDataSources) {
        for (id username in [_chatDataSources allKeys]) {
            ChatDataSource * chatDataSource = [self getDataSourceForFriendname: username];
            NSString * spot = [ChatUtils getSpotUserA: _username userB: username];
            
            DDLogVerbose(@"getting message and control data for spot: %@",spot );
            NSMutableDictionary * messageId = [[NSMutableDictionary alloc] init];
            [messageId setObject: username forKey:@"u"];
            [messageId setObject: [NSNumber numberWithInteger: [chatDataSource latestHttpMessageId]] forKey:@"m"];
            [messageId setObject: [NSNumber numberWithInteger:[chatDataSource latestControlMessageId]] forKey:@"cm"];
            [messageIds addObject:messageId];
        }
    }
    
    
    DDLogVerbose(@"before network call");
    
    
    [[[NetworkManager sharedInstance] getNetworkController:_username] getLatestDataSinceUserControlId: _homeDataSource.latestUserControlId spotIds:messageIds successBlock:^(NSURLSessionTask *task, id JSON) {
        
        DDLogVerbose(@"network call complete");
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if ([JSON objectForKey:@"sigs2"]) {
                NSDictionary * sigs = [[IdentityController sharedInstance] updateSignatures: _username];
                [[[NetworkManager sharedInstance] getNetworkController:_username] updateSigs:sigs];
            }
        });
        
        NSDictionary * conversationIds = [JSON objectForKey:@"conversationIds"];
        if (conversationIds) {
            
            NSEnumerator * keyEnumerator = [conversationIds keyEnumerator];
            NSString * spot;
            while (spot = [keyEnumerator nextObject]) {
                
                NSInteger availableId = [[conversationIds objectForKey:spot] integerValue];
                NSString * user = [ChatUtils getOtherUserFromSpot:spot andUser:_username];
                [_homeDataSource setAvailableMessageId:availableId forFriendname: user suppressNew: suppressNew];
            }
        }
        
        NSDictionary * controlIds = [JSON objectForKey:@"controlIds"];
        if (controlIds) {
            NSEnumerator * keyEnumerator = [controlIds keyEnumerator];
            NSString * spot;
            while (spot = [keyEnumerator nextObject]) {
                NSInteger availableId = [[controlIds objectForKey:spot] integerValue];
                NSString * user = [ChatUtils getOtherUserFromSpot:spot andUser:_username];
                
                [_homeDataSource setAvailableMessageControlId:availableId forFriendname: user];
            }
        }
        
        NSArray * userControlMessages = [JSON objectForKey:@"userControlMessages"];
        if (userControlMessages ) {
            [self handleUserControlMessages: userControlMessages];
        }
        
        //update message data
        NSArray * messageDatas = [JSON objectForKey:@"messageData"];
        for (NSDictionary * messageData in messageDatas) {
            
            
            NSString * friendname = [messageData objectForKey:@"username"];
            NSArray * controlMessages = [messageData objectForKey:@"controlMessages"];
            if (controlMessages) {
                [self handleControlMessages:controlMessages forUsername:friendname ];
            }
            
            NSArray * messages = [messageData objectForKey:@"messages"];
            if (messages) {
                
                [self handleMessages: messages forUsername:friendname];
            }
        }
        
        //clear notifications and badges
        [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
        [SharedUtils clearBadgeCount];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 0];
        [SharedUtils setActive:YES];
        
        //handle autoinvites
        [self handleAutoinvites];
        
        [self stopProgress:@"socket"];
        [_homeDataSource postRefresh];
        [self processNextMessage];
    } failureBlock:^(NSURLSessionTask *task, NSError *Error) {
        DDLogWarn(@"getLatestData failed: %@", Error.localizedDescription);
        [self stopProgress:@"socket"];
        
        long statusCode = [(NSHTTPURLResponse *) task.response statusCode];
        
        if (statusCode != 401) {
            [UIUtils showToastKey:@"loading_latest_messages_failed"];
        }
    }];
}

- (HomeDataSource *) getHomeDataSource {
    
    if (_homeDataSource == nil) {
        _homeDataSource = [[HomeDataSource alloc] init: _username];
    }
    return _homeDataSource;
}


- (void) sendTextMessage: (NSString *) message toFriendname: (NSString *) friendname
{
    if ([UIUtils stringIsNilOrEmpty:friendname]) return;
    
    Friend * afriend = [_homeDataSource getFriendByName:friendname];
    if ([afriend isDeleted]) return;
    
    DDLogVerbose(@"message: %@", message);
    
    NSData * iv = [EncryptionController getIv];
    NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:friendname forKey:@"to"];
    [dict setObject:_username forKey:@"from"];
    [dict setObject:b64iv forKey:@"iv"];
    [dict setObject:MIME_TYPE_TEXT forKey:@"mimeType"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"hashed"];
    
    SurespotMessage * sm =[[SurespotMessage alloc] initWithDictionary: dict];
    
    //cache the plain data locally
    sm.plainData = message;
    [UIUtils setTextMessageHeights:sm size:[UIScreen mainScreen].bounds.size ourUsername:_username];
    
    ChatDataSource * dataSource = [self getDataSourceForFriendname: friendname];
    [dataSource addMessage: sm refresh:NO];
    [dataSource postRefresh];
    
    [self enqueueMessage:sm];
}

- (void) sendGifLinkUrl:(NSString *)url to:(NSString *)friendname
{
    if ([UIUtils stringIsNilOrEmpty:friendname]) return;
    
    Friend * afriend = [_homeDataSource getFriendByName:friendname];
    if ([afriend isDeleted]) return;
    
    
    NSData * iv = [EncryptionController getIv];
    NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:friendname forKey:@"to"];
    [dict setObject:_username forKey:@"from"];
    [dict setObject:b64iv forKey:@"iv"];
    [dict setObject:MIME_TYPE_GIF_LINK forKey:@"mimeType"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"hashed"];
    
    SurespotMessage * sm =[[SurespotMessage alloc] initWithDictionary: dict];
    
    //cache the plain data locally
    sm.plainData = url;
    [UIUtils setImageMessageHeights:sm size:[UIScreen mainScreen].bounds.size];
    
    ChatDataSource * dataSource = [self getDataSourceForFriendname: friendname];
    [dataSource addMessage: sm refresh:NO];
    [dataSource postRefresh];
    
    [self enqueueMessage:sm];
}



-(void) sendImageMessage: (NSString*) localUrlOrId  to: (NSString *) friendname {
    //add message locally
    NSData * iv = [EncryptionController getIv];
    NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:friendname forKey:@"to"];
    [dict setObject:_username forKey:@"from"];
    [dict setObject:b64iv forKey:@"iv"];
    [dict setObject:MIME_TYPE_IMAGE forKey:@"mimeType"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"hashed"];
    
    SurespotMessage * sm =[[SurespotMessage alloc] initWithDictionary: dict];
    
    //cache the plain data locally
    sm.plainData = localUrlOrId;
    
    DDLogDebug(@"sendImageMessage adding local image message, url: %@", sm.plainData);
    
    [UIUtils setImageMessageHeights:sm size:[UIScreen mainScreen].bounds.size];
    
    ChatDataSource * dataSource = [self getDataSourceForFriendname: friendname];
    [dataSource addMessage: sm refresh:NO];
    [dataSource postRefresh];
    
    [self enqueueMessage:sm];
}

-(void) sendVoiceMessage: (NSURL*) localUrl  to: (NSString *) friendname {
    //add message locally
    NSData * iv = [EncryptionController getIv];
    NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:friendname forKey:@"to"];
    [dict setObject:_username forKey:@"from"];
    [dict setObject:b64iv forKey:@"iv"];
    [dict setObject:MIME_TYPE_M4A forKey:@"mimeType"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"hashed"];
    
    SurespotMessage * sm = [[SurespotMessage alloc] initWithDictionary: dict];
    
    //cache the plain data locally
    sm.plainData = [localUrl absoluteString];
    
    DDLogDebug(@"sendVoiceMessage adding local voice message, url: %@", sm.plainData);
    
    [UIUtils setVoiceMessageHeights: sm size:[UIScreen mainScreen].bounds.size];
    
    ChatDataSource * dataSource = [self getDataSourceForFriendname: friendname];
    [dataSource addMessage: sm refresh:NO];
    [dataSource postRefresh];
    
    [self enqueueMessage:sm];
}

-(void) enqueueMessage: (SurespotMessage * ) message {
    // check that the message isn't a duplicate
    DDLogInfo(@"enqueing message %@", message);
    @synchronized (_messageBuffer) {
        if (![_messageBuffer containsObject:message]) {
            [_messageBuffer addObject:message];
        }
    }
    [self processNextMessage];
}

-(void) processNextMessage {
    
    if([_messageBuffer count] > 0) {
        SurespotMessage * qm = [_messageBuffer objectAtIndex:0];
        
        //see if it's been sent
        ChatDataSource * cds = [self getDataSourceForFriendname:[qm getOtherUser:_username]];
        if ([[cds getMessageByIv: qm.iv] serverid] > 0) {
            DDLogDebug(@"Message %@ already sent, cancelling send operation", qm);
            [self removeMessageFromBuffer:qm];
            [self processNextMessage];
            return;
        }
        
        //see if we have an operation for this message, and if not create one
        SendMessageOperation * smo;
        for (SendMessageOperation * operation in [_messageSendQueue operations]) {
            if ([SurespotMessage areMessagesEqual:qm message:[operation message]]) {
                smo = operation;
                break;
            }
        }
        
        if (!smo) {
            if ([qm.mimeType isEqualToString:MIME_TYPE_TEXT] || [qm.mimeType isEqualToString:MIME_TYPE_GIF_LINK]) {
                DDLogVerbose(@"Creating send text message operation for %@", qm.iv);
                [_messageSendQueue addOperation: [[SendTextMessageOperation alloc] initWithMessage:qm callback:^(SurespotMessage * message) {
                    if (message) {
                        [self removeMessageFromBuffer:message];
                        [self processNextMessage];
                    }
                    else {
                        //no message, error message queue
                        //when queue loads again it will recreate the operations
                        //todo show notification - can't do it till ios 10
                        DDLogDebug(@"Message text send operation finished with no message, cancelling message send operations");
                        [_messageSendQueue cancelAllOperations];
                    }
                }]];
            }
            else {
                if ([qm.mimeType isEqualToString:MIME_TYPE_IMAGE]) {
                    DDLogVerbose(@"Creating send image message operation for %@", qm.iv);
                    [_messageSendQueue addOperation: [[SendImageMessageOperation alloc] initWithMessage:qm callback:^(SurespotMessage * message) {
                        if (message) {
                            [self removeMessageFromBuffer:message];
                            [self processNextMessage];
                        }
                        
                        else {
                            //no message, error message queue
                            //when queue loads again it will recreate the operations
                            //todo show notification, can't do it till ios 10
                            DDLogDebug(@"Message send image operation finished with no message");
                            [_messageSendQueue cancelAllOperations];
                        }
                    }]];
                }
                else {
                    if ([qm.mimeType isEqualToString:MIME_TYPE_M4A]) {
                        DDLogVerbose(@"Creating send voice message operation for %@", qm.iv);
                        [_messageSendQueue addOperation: [[SendVoiceMessageOperation alloc] initWithMessage:qm callback:^(SurespotMessage * message) {
                            if (message) {
                                [self removeMessageFromBuffer:message];
                                [self processNextMessage];
                            }
                            
                            else {
                                //no message, error message queue
                                //when queue loads again it will recreate the operations
                                //todo show notification, can't do it till ios 10
                                DDLogDebug(@"Message send voice operation finished with no message");
                                [_messageSendQueue cancelAllOperations];
                            }
                        }]];
                    }
                }
            }
        }
    }
}




//
//-(void) sendMessageOnSocket: (SurespotMessage *) message {
//    //array doesn't seem to work
//    [self.socket  emit: @"message" with: @[[message toNSDictionary]]];
//}

-(void) removeDuplicates: (NSMutableArray *) sendBuffer {
    for (int forwardIdx = 0; forwardIdx < ((int)sendBuffer.count); forwardIdx++) {
        SurespotMessage* originalMessage = sendBuffer[forwardIdx];
        for (int i = ((int)sendBuffer.count) - 1; i > forwardIdx; i--) {
            SurespotMessage* possibleDuplicate = sendBuffer[i];
            if ([SurespotMessage areMessagesEqual:originalMessage message:possibleDuplicate] == YES) {
                DDLogInfo(@"Removed duplicate message %@", possibleDuplicate);
                [sendBuffer removeObjectAtIndex:i];
            }
        }
    }
}

-(SurespotMessage *) removeMessageFromBuffer: (SurespotMessage *) removeMessage  {
    __block SurespotMessage * foundMessage = nil;
    
    [_messageBuffer enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SurespotMessage * message, NSUInteger idx, BOOL *stop) {
        if([removeMessage.iv isEqualToString: message.iv]) {
            foundMessage = message;
            *stop = YES;
        }
    }];
    
    if (foundMessage ) {
        [_messageBuffer removeObject:foundMessage];
        DDLogDebug(@"removed message from message buffer, iv: %@, count: %lu", foundMessage.iv, (unsigned long)_messageBuffer.count);
    }
    
    for (SendMessageOperation * stmo in _messageSendQueue.operations) {
        if ([stmo.message isEqual:removeMessage]) {
            [stmo cancel];
            DDLogDebug(@"cancelled message send operation for, iv: %@, count: %lu", removeMessage.iv, (unsigned long)_messageSendQueue.operations.count);
        }
    }
    
    return foundMessage;
}

-(void) handleErrorMessage: (SurespotErrorMessage *) errorMessage {
    __block SurespotMessage * foundMessage = nil;
    
    [_messageBuffer enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SurespotMessage * message, NSUInteger idx, BOOL *stop) {
        if([errorMessage.data isEqualToString: message.iv]) {
            foundMessage = message;
            *stop = YES;
        }
    }];
    
    if (foundMessage ) {
        [_messageBuffer removeObject:foundMessage];
        foundMessage.errorStatus = errorMessage.status;
        ChatDataSource * cds = [self getDataSourceForFriendname:[foundMessage getOtherUser: _username]];
        if (cds) {
            [cds postRefresh];
        }
    }
}


-(void) handleMessage: (SurespotMessage *) message {
    NSString * otherUser = [message getOtherUser: _username];
    BOOL isNew = YES;
    ChatDataSource * cds = [self getDataSourceForFriendname:otherUser];
    if (cds) {
        isNew = [cds addMessage: message refresh:YES];
    }
    
    DDLogInfo(@"isnew: %d", isNew);
    
    //update ids
    Friend * afriend = [_homeDataSource getFriendByName:otherUser];
    if (afriend && message.serverid > 0) {
        afriend.availableMessageId = message.serverid;
        
        if (cds) {
            afriend.lastReceivedMessageId = message.serverid;
            
            if ([[_homeDataSource getCurrentChat] isEqualToString: otherUser]) {
                afriend.hasNewMessages = NO;
            }
            else {
                afriend.hasNewMessages = isNew;
            }
        }
        else {
            
            if (![[_homeDataSource getCurrentChat] isEqualToString: otherUser] ) {
                afriend.hasNewMessages = isNew;
            }
        }
        
        
        
        [_homeDataSource postRefresh];
    }
    
    DDLogInfo(@"hasNewMessages: %d", afriend.hasNewMessages);
    
    //if we have new message let anyone who cares know
    if (afriend.hasNewMessages) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"newMessage" object: message];
    }
}

-(void) handleMessages: (NSArray *) messages forUsername: (NSString *) username {
    if (messages && [messages count ] > 0) {
        ChatDataSource * cds = nil;
        BOOL isNew = YES;
        @synchronized (_chatDataSources) {
            cds = [_chatDataSources objectForKey:username];
        }
        
        isNew = [cds handleMessages: messages];
        
        Friend * afriend = [_homeDataSource getFriendByName:username];
        if (afriend) {
            
            SurespotMessage * message = [[SurespotMessage alloc] initWithDictionary:[messages objectAtIndex:[messages count ] -1]];
            
            if  (message.serverid > 0) {
                
                afriend.availableMessageId = message.serverid;
                
                if (cds) {
                    afriend.lastReceivedMessageId = message.serverid;
                    
                    if ([[_homeDataSource getCurrentChat] isEqualToString: username]) {
                        afriend.hasNewMessages = NO;
                    }
                    else {
                        afriend.hasNewMessages = isNew;
                    }
                }
                else {
                    
                    if (![[_homeDataSource getCurrentChat] isEqualToString: username] ) {
                        afriend.hasNewMessages = isNew;
                    }
                }
                
                [_homeDataSource postRefresh];
            }
        }
        
        [cds postRefresh];
    }
}
-(void) handleControlMessage: (SurespotControlMessage *) message {
    
    if ([message.type isEqualToString:@"user"]) {
        [self handleUserControlMessage: message];
    }
    else {
        if ([message.type isEqualToString:@"message"]) {
            NSString * otherUser = [ChatUtils getOtherUserFromSpot:message.data andUser:_username];
            ChatDataSource * cds = [_chatDataSources objectForKey:otherUser];
            
            
            if (cds) {
                [cds handleControlMessage:message];
            }
            
            
            Friend * thefriend = [_homeDataSource getFriendByName:otherUser];
            if (thefriend) {
                
                NSInteger messageId = message.controlId;
                
                thefriend.availableMessageControlId = messageId;
            }
        }
    }
}

-(void) handleControlMessages: (NSArray *) controlMessages forUsername: (NSString *) username {
    if (controlMessages && [controlMessages count] > 0) {
        ChatDataSource * cds = nil;
        @synchronized (_chatDataSources) {
            cds = [_chatDataSources objectForKey:username];
        }
        
        if (cds) {
            [cds handleControlMessages:controlMessages];
        }
    }
}

-(void) handleUserControlMessages: (NSArray *) controlMessages {
    for (id jsonMessage in controlMessages) {
        
        
        SurespotControlMessage * message = [[SurespotControlMessage alloc] initWithDictionary: jsonMessage];
        [self handleUserControlMessage:message];
    }
}

-(void) handleUserControlMessage: (SurespotControlMessage *) message {
    if (message.controlId > _homeDataSource.latestUserControlId) {
        DDLogDebug(@"handleUserControlMessage setting latestUserControlId: %ld", (long)message.controlId);
        _homeDataSource.latestUserControlId = message.controlId;
    }
    NSString * user;
    if ([message.action isEqualToString:@"revoke"]) {
        [[IdentityController sharedInstance] updateLatestVersionForUsername: message.data version: message.moreData];
    }
    else {
        if ([message.action isEqualToString:@"invited"]) {
            user = message.data;
            [_homeDataSource addFriendInvited:user];
        }
        else {
            if ([message.action isEqualToString:@"added"]) {
                [self friendAdded:[message data] acceptedBy: [message moreData]];
            }
            else {
                if ([message.action isEqualToString:@"invite"]) {
                    user = message.data;
                    
                    [[SoundController sharedInstance] playInviteSoundForUser: _username];
                    [_homeDataSource addFriendInviter: user ];
                }
                else {
                    if ([message.action isEqualToString:@"ignore"]) {
                        [self friendIgnore: message.data];
                    }
                    else {
                        if ([message.action isEqualToString:@"delete"]) {
                            [self friendDelete: message ];
                            
                        }
                        else {
                            if ([message.action isEqualToString:@"friendImage"]) {
                                [self handleFriendImage: message ];
                                
                            }
                            else {
                                if ([message.action isEqualToString:@"friendAlias"]) {
                                    [self handleFriendAlias: message ];
                                    
                                }
                            }
                        }
                        
                    }
                }
            }
        }
    }
}

-(void) inviteAction:(NSString *) action forUsername:(NSString *)username{
    DDLogVerbose(@"Invite action: %@, for username: %@", action, username);
    [self startProgress: @"inviteAction"];
    [[[NetworkManager sharedInstance] getNetworkController:_username]  respondToInviteName:username action:action
     
     
                                                                              successBlock:^(NSURLSessionTask * task, id responseObject) {
                                                                                  
                                                                                  Friend * afriend = [_homeDataSource getFriendByName:username];
                                                                                  [afriend setInviter:NO];
                                                                                  
                                                                                  if ([action isEqualToString:@"accept"]) {
                                                                                      [_homeDataSource setFriend: username] ;
                                                                                  }
                                                                                  else {
                                                                                      if ([action isEqualToString:@"block"]||[action isEqualToString:@"ignore"]) {
                                                                                          if (![afriend isDeleted]) {
                                                                                              [_homeDataSource removeFriend:afriend withRefresh:YES];
                                                                                          }
                                                                                          else {
                                                                                              [_homeDataSource postRefresh];
                                                                                          }
                                                                                      }
                                                                                  }
                                                                                  [self stopProgress: @"inviteAction"];
                                                                              }
     
                                                                              failureBlock:^(NSURLSessionTask *operation, NSError *Error) {
                                                                                  DDLogError(@"error responding to invite: %@", Error);
                                                                                  if ([(NSHTTPURLResponse*) operation.response statusCode] != 404) {
                                                                                      
                                                                                      [UIUtils showToastKey:@"could_not_respond_to_invite"];
                                                                                  }
                                                                                  else {
                                                                                      [_homeDataSource postRefresh];
                                                                                  }
                                                                                  [self stopProgress: @"inviteAction"];
                                                                              }];
    
}


- (void) inviteUser: (NSString *) username {
    NSString * loggedInUser = _username;
    if ([UIUtils stringIsNilOrEmpty:username] || [username isEqualToString:loggedInUser]) {
        return;
    }
    
    [self startProgress: @"inviteUser"];
    [[[NetworkManager sharedInstance] getNetworkController:_username]
     inviteFriend:username
     successBlock:^(NSURLSessionTask *operation, id responseObject) {
         DDLogVerbose(@"invite friend response: %ld",  (long)[(NSHTTPURLResponse*) operation.response statusCode]);
         
         [_homeDataSource addFriendInvited:username];
         [self stopProgress: @"inviteUser"];
     }
     failureBlock:^(NSURLSessionTask *operation, NSError *Error) {
         
         DDLogVerbose(@"response failure: %@",  Error);
         
         switch ([(NSHTTPURLResponse*) operation.response statusCode]) {
             case 404:
                 [UIUtils showToastKey: @"user_does_not_exist"];
                 break;
             case 409:
                 [UIUtils showToastKey: @"you_are_already_friends"];
                 break;
             case 403:
                 [UIUtils showToastKey: @"already_invited"];
                 break;
             default:
                 [UIUtils showToastKey:@"could_not_invite"];
         }
         
         [self stopProgress: @"inviteUser"];
     }];
    
}



- (void)friendAdded:(NSString *) username acceptedBy:(NSString *) byUsername
{
    DDLogInfo(@"friendAdded: %@, by: %@",username, byUsername);
    [_homeDataSource setFriend: username];
    
    //if i'm not the accepter fire a notification saying such
    if (![byUsername isEqualToString:_username]) {
        [UIUtils showToastMessage:[NSString stringWithFormat:NSLocalizedString(@"notification_invite_accept", nil), _username, byUsername] duration:1];
        [[SoundController sharedInstance] playInviteAcceptedSoundForUser:_username];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"inviteAccepted" object:byUsername];
        });
    }
    
}

-(void) friendIgnore: (NSString * ) name {
    DDLogVerbose(@"entered");
    Friend * afriend = [_homeDataSource getFriendByName:name];
    
    if (afriend) {
        if (![afriend isDeleted]) {
            [_homeDataSource removeFriend:afriend withRefresh:NO];
        }
        else {
            [afriend setInvited:NO];
            [afriend setInviter:NO];
        }
        
    }
    
    [_homeDataSource postRefresh];
    
    
}


- (void)friendDelete: (SurespotControlMessage *) message
{
    DDLogVerbose(@"entered");
    Friend * afriend = [_homeDataSource getFriendByName:[message data]];
    
    if (afriend) {
        if ([afriend isInvited] || [afriend isInviter]) {
            if (![afriend isDeleted]) {
                [_homeDataSource removeFriend:afriend withRefresh:NO];
            }
            else {
                [afriend setInvited:NO];
                [afriend setInviter:NO];
            }
        }
        else {
            [self handleDeleteUser: [message data] deleter:[message moreData]];
        }
    }
    
    [_homeDataSource postRefresh];
}

-(void) handleDeleteUser: (NSString *) deleted deleter: (NSString *) deleter {
    DDLogVerbose(@"entered");
    
    
    Friend * theFriend = [_homeDataSource getFriendByName:deleted];
    
    if (theFriend) {
        
        BOOL iDeleted = [deleter isEqualToString:_username];
        NSArray * data = [NSArray arrayWithObjects:theFriend.name, [NSNumber numberWithBool: iDeleted], nil];
        
        
        if (iDeleted) {
            //get latest version
            [[CredentialCachingController sharedInstance] getLatestVersionForOurUsername: _username theirUsername: deleted callback:^(NSString *version) {
                
                //fire this first so tab closes and saves data before we delete all the data
                [[NSNotificationCenter defaultCenter] postNotificationName:@"deleteFriend" object: data];
                
                
                [_homeDataSource removeFriend:theFriend withRefresh:YES];
                
                //wipe user state
                [FileController wipeDataForUsername:_username friendUsername:deleted];
                
                //clear cached user data
                [[CredentialCachingController sharedInstance] clearUserData: deleted];
                
                
                //clear http cache
                NSInteger maxVersion = [version integerValue];
                for (NSInteger i=1;i<=maxVersion;i++) {
                    // NSString * path = [[[NetworkManager sharedInstance] getNetworkController:_username] buildPublicKeyPathForUsername:deleted version: [@(i) stringValue]];
                    // [[[NetworkManager sharedInstance] getNetworkController:_username] deleteFromCache: path];
                }
            }];
        }
        else {
            [theFriend setDeleted];
            
            ChatDataSource * cds = [_chatDataSources objectForKey:deleter];
            if (cds) {
                [cds  userDeleted];
            }
            
            //fire this last because the friend needs to be deleted to update controls
            [[NSNotificationCenter defaultCenter] postNotificationName:@"deleteFriend" object: data];
        }
        
    }
}

- (void)handleFriendImage: (SurespotControlMessage *) message  {
    Friend * theFriend = [_homeDataSource getFriendByName:message.data];
    
    if (theFriend) {
        if (message.moreData) {
            [self setFriendImageUrl:[message.moreData objectForKey:@"url"]
                      forFriendname: message.data
                            version:[message.moreData objectForKey:@"version"]
                                 iv:[message.moreData objectForKey:@"iv"]
                             hashed:[[message.moreData objectForKey:@"imageHashed"] boolValue]];
        }
        else {
            [_homeDataSource removeFriendImage:message.data];
        }
    }
}

- (void) setCurrentChat: (NSString *) username {
    [_homeDataSource setCurrentChat: username];
    //here is where we would set message read stuff
    
}

-(NSString *) getCurrentChat {
    NSString * currentChat = [_homeDataSource getCurrentChat];
    DDLogInfo(@"currentChat: %@", currentChat);
    return currentChat;
}


//-(void) login {
//    DDLogInfo(@"login");
//    // [self connect];
//    _homeDataSource = [[HomeDataSource alloc] init: _username];
//}

-(void) logout {
    DDLogInfo(@"logout");
    [_homeDataSource closeAllChats];
    [self pause];
    //deal with message queue
}

- (void) deleteFriend: (Friend *) thefriend {
    if (thefriend) {
        NSString * username = _username;
        NSString * friendname = thefriend.name;
        
        [self startProgress: @"deleteFriend"];
        
        [[[NetworkManager sharedInstance] getNetworkController:_username] deleteFriend:friendname successBlock:^(NSURLSessionTask *operation, id responseObject) {
            [self handleDeleteUser:friendname deleter:username];
            [self stopProgress: @"deleteFriend"];
        } failureBlock:^(NSURLSessionTask *operation, NSError *error) {
            [UIUtils showToastKey:@"could_not_delete_friend"];
            [self stopProgress: @"deleteFriend"];
        }];
    }
}

-(void) deleteMessage: (SurespotMessage *) message {
    if (message) {
        ChatDataSource * cds = [_chatDataSources objectForKey:[message getOtherUser: _username]];
        if (cds) {
            if (message.serverid > 0) {
                
                [self startProgress: @"deleteMessage"];
                [[[NetworkManager sharedInstance] getNetworkController:_username] deleteMessageName:[message getOtherUser: _username] serverId:[message serverid] successBlock:^(NSURLSessionTask *operation, id responseObject) {
                    [cds deleteMessage: message initiatedByMe: YES];
                    [self removeMessageFromBuffer:message];
                    [self stopProgress: @"deleteMessage"];
                } failureBlock:^(NSURLSessionTask *operation, NSError *error) {
                    
                    
                    //if it's 404, delete it locally as it's not on the server
                    if ([(NSHTTPURLResponse*) operation.response statusCode] == 404) {
                        [cds deleteMessage: message initiatedByMe: YES];
                    }
                    else {
                        [UIUtils showToastKey:@"could_not_delete_message"];
                    }
                    [self stopProgress: @"deleteMessage"];
                }];
                
            }
            else {
                [cds deleteMessageByIv: [message iv] ];
                [self removeMessageFromBuffer:message];
            }
        }
    }
}


- (void) deleteMessagesForFriend: (Friend  *) afriend {
    ChatDataSource * cds = [self getDataSourceForFriendname:afriend.name];
    
    long lastMessageId = 0;
    if (cds) {
        lastMessageId = [cds latestMessageId];
    }
    else {
        lastMessageId = [afriend lastReceivedMessageId];
    }
    [self startProgress: @"deleteMessagesForFriend"];
    [[[NetworkManager sharedInstance] getNetworkController:_username] deleteMessagesUTAI:lastMessageId name:afriend.name successBlock:^(NSURLSessionTask *operation, id responseObject) {
        
        [cds deleteAllMessagesUTAI:lastMessageId];
        [self stopProgress: @"deleteMessagesForFriend"];
        
    } failureBlock:^(NSURLSessionTask *operation, NSError *error) {
        [UIUtils showToastKey:@"could_not_delete_messages"];
        [self stopProgress: @"deleteMessagesForFriend"];
    }];
    
    
}


-(void) loadEarlierMessagesForUsername: username callback: (CallbackBlock) callback {
    ChatDataSource * cds = [self getDataSourceForFriendname:username];
    [cds loadEarlierMessagesCallback:callback];
    
}

-(void) startProgress: (NSString *) key {
    DDLogInfo(@"startProgress");
    NSDictionary* userInfo = @{@"key": key};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"startProgress" object: self userInfo:userInfo];
}

-(void) stopProgress: (NSString *) key {
    DDLogInfo(@"stopProgress");
    NSDictionary* userInfo = @{@"key": key};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"stopProgress" object: self userInfo:userInfo];
}

-(void) toggleMessageShareable: (SurespotMessage *) message {
    if (message) {
        ChatDataSource * cds = [_chatDataSources objectForKey:[message getOtherUser: _username]];
        if (cds) {
            if (message.serverid > 0) {
                
                [self startProgress: @"toggleMessageShareable"];
                [[[NetworkManager sharedInstance] getNetworkController:_username] setMessageShareable:[message getOtherUser: _username] serverId:[message serverid] shareable:!message.shareable successBlock:^(NSURLSessionTask *operation, id responseObject) {
                    [cds setMessageId: message.serverid shareable: [[[NSString alloc] initWithData: responseObject encoding:NSUTF8StringEncoding] isEqualToString:@"shareable"] ? YES : NO];
                    [self stopProgress: @"toggleMessageShareable"];
                } failureBlock:^(NSURLSessionTask *operation, NSError *error) {
                    [UIUtils showToastKey:@"could_not_set_message_lock_state"];
                    [self stopProgress: @"toggleMessageShareable"];
                }];
                
            }
        }
    }
}

-(void) handleAutoinvites {
    
    NSMutableArray * autoinvites  = [NSMutableArray arrayWithArray: [[NSUserDefaults standardUserDefaults] stringArrayForKey: @"autoinvites"]];
    if ([autoinvites count] > 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"autoinvites"];
        NSMutableString * exists = [NSMutableString new];
        for (NSString * username in autoinvites) {
            if (![_homeDataSource getFriendByName:username]) {
                [self inviteUser:username];
            }
            else {
                [exists appendString: [username stringByAppendingString:@" "]];
            }
        }
        
        if ([exists length] > 0) {
            [UIUtils showToastMessage:[NSString stringWithFormat: NSLocalizedString(@"autoinvite_user_exists", nil), exists] duration:2];
        }
        
    }
}

-(void) setFriendImageUrl: (NSString *) url forFriendname: (NSString *) name version: (NSString *) version iv: (NSString *) iv  hashed:(BOOL)hashed {
    [_homeDataSource setFriendImageUrl:url forFriendname:name version:version iv:iv hashed:hashed];
}

-(void) assignFriendAlias: (NSString *) alias toFriendName: (NSString *) friendname  callbackBlock: (CallbackBlock) callbackBlock {
    [self startProgress: @"assignFriendAlias"];
    NSString * version = [[IdentityController sharedInstance] getOurLatestVersion: _username];
    NSString * username = _username;
    NSData * iv = [EncryptionController getIv];
    NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
    //encrypt
    [EncryptionController symmetricEncryptData:[alias dataUsingEncoding:NSUTF8StringEncoding]
                                   ourUsername:_username
                                    ourVersion:version
                                 theirUsername:username
                                  theirVersion:version
                                            iv:b64iv
                                      callback:^(NSData * encryptedAliasData) {
                                          if (encryptedAliasData) {
                                              NSString * b64data = [encryptedAliasData base64EncodedStringWithSeparateLines:NO];
                                              
                                              //upload friend image to server
                                              DDLogInfo(@"assigning friend alias");
                                              [[[NetworkManager sharedInstance] getNetworkController:_username]
                                               assignFriendAlias:b64data
                                               friendname:friendname
                                               version:version
                                               iv:b64iv
                                               successBlock:^(NSURLSessionTask *operation, id responseObject) {
                                                   [self setFriendAlias: alias  data: b64data friendname: friendname version: version iv: b64iv hashed:YES];
                                                   callbackBlock([NSNumber numberWithBool:YES]);
                                                   [self stopProgress: @"assignFriendAlias"];
                                               } failureBlock:^(NSURLSessionTask *operation, NSError *error) {
                                                   callbackBlock([NSNumber numberWithBool:NO]);
                                                   [self stopProgress: @"assignFriendAlias"];
                                               }];
                                          }
                                          else {
                                              callbackBlock([NSNumber numberWithBool:NO]);
                                              [self stopProgress: @"assignFriendAlias"];
                                          }
                                      }];
    
    
    
    
}

-(void) setFriendAlias: (NSString *) alias data: (NSString *) data friendname: (NSString *) friendname version: (NSString *) version iv: (NSString *) iv hashed:(BOOL)hashed {
    [_homeDataSource setFriendAlias: alias data: data friendname: friendname version: version iv: iv hashed:hashed];
}

- (void)handleFriendAlias: (SurespotControlMessage *) message  {
    Friend * theFriend = [_homeDataSource getFriendByName:message.data];
    if (theFriend) {
        if (message.moreData) {
            [self setFriendAlias:nil data:[message.moreData objectForKey:@"data"]
                      friendname:message.data
                         version:[message.moreData objectForKey:@"version"]
                              iv:[message.moreData objectForKey:@"iv"]
                          hashed:[[message.moreData objectForKey:@"aliasHashed"] boolValue]];
        }
        else {
            [_homeDataSource removeFriendAlias: message.data];
        }
    }
}

-(void) removeFriendAlias: (NSString *) friendname callbackBlock: (CallbackBlock) callbackBlock {
    [self startProgress: @"removeFriendAlias"];
    [[[NetworkManager sharedInstance] getNetworkController:_username]
     deleteFriendAlias:friendname
     successBlock:^(NSURLSessionTask *operation, id responseObject) {
         [_homeDataSource removeFriendAlias: friendname];
         callbackBlock([NSNumber numberWithBool:YES]);
         [self stopProgress: @"removeFriendAlias"];
     } failureBlock:^(NSURLSessionTask *operation, NSError *error) {
         callbackBlock([NSNumber numberWithBool:NO]);
         [self stopProgress: @"removeFriendAlias"];
     }];
}
-(void) removeFriendImage: (NSString *) friendname callbackBlock: (CallbackBlock) callbackBlock {
    [self startProgress: @"removeFriendImage"];
    [[[NetworkManager sharedInstance] getNetworkController:_username]
     deleteFriendImage:friendname
     successBlock:^(NSURLSessionTask *operation, id responseObject) {
         [_homeDataSource removeFriendImage: friendname];
         callbackBlock([NSNumber numberWithBool:YES]);
         [self stopProgress: @"removeFriendImage"];
     } failureBlock:^(NSURLSessionTask *operation, NSError *error) {
         callbackBlock([NSNumber numberWithBool:NO]);
         [self stopProgress: @"removeFriendImage"];
     }];
}

@end
