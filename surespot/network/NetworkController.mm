//
//  NetworkController.m
//  surespot
//
//  Created by Adam on 6/16/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "IdentityController.h"
#import "NetworkController.h"
#import "ChatUtils.h"
#import "DDLog.h"
#import "NSData+Base64.h"
#import "NSData+SRB64Additions.h"
#import "EncryptionController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface NetworkController()
@property (nonatomic, strong) NSString * baseUrl;
@property (atomic, assign) BOOL loggedOut;
@end

@implementation NetworkController

+(NetworkController*)sharedInstance
{
    static NetworkController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
        
    });
    
    return sharedInstance;
}

-(NetworkController*)init
{
    //call super init
    self = [super initWithBaseURL:[NSURL URLWithString: baseUrl]];
    
    if (self != nil) {
        _baseUrl = baseUrl;
        
        [self.requestSerializer setValue:[NSString stringWithFormat:@"%@/%@ (%@; CPU iPhone OS 7_0_4; Scale/%0.2f)", [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleExecutableKey] ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleIdentifierKey], (__bridge id)CFBundleGetValueForInfoDictionaryKey(CFBundleGetMainBundle(), kCFBundleVersionKey) ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f)] forHTTPHeaderField:@"User-Agent"];
        
        self.responseSerializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:@[[AFJSONResponseSerializer serializer],
                                                                                                            [AFHTTPResponseSerializer serializer]]];
        
        
        //        [self setDefaultHeader:@"Accept-Charset" value:@"utf-8"];
        
        //        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(HTTPOperationDidFinish:) name:AFNetworkingOperationDidFinishNotification object:nil];
    }
    
    return self;
}


//handle 401s globally
- (void)HTTPOperationDidFinish:(NSNotification *)notification {
    //TODO figure out token refresh
    //    AFHTTPRequestOperation *operation = (AFHTTPRequestOperation *)[notification object];
    //
    //    if (![operation isKindOfClass:[AFHTTPRequestOperation class]]) {
    //        return;
    //    }
    //
    //    if ([operation.response statusCode] == 401) {
    //        DDLogInfo(@"path components: %@", operation.request.URL.pathComponents[1]);
    //        //ignore on logout
    //        if (![operation.request.URL.pathComponents[1] isEqualToString:@"logout"]) {
    //            DDLogInfo(@"received 401");
    //            [self setUnauthorized];
    //        }
    //        else {
    //            DDLogInfo(@"logout 401'd");
    //        }
    //    }
}

-(void) setUnauthorized {
    _loggedOut = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"unauthorized" object: nil];
}

-(void) clearCookies {
    //clear the cookie store
    for (NSHTTPCookie * cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
}

-(void) loginWithUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
             successBlock:(JSONCookieSuccessBlock) successBlock failureBlock: (JSONFailureBlock) failureBlock
{
    [self clearCookies];
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   versionString, @"version",
                                   @"ios", @"platform", nil];
    
    [self addPurchaseReceiptToParams:params];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    
    [self POST:@"login"
    parameters:params
      progress:nil
       success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable JSON) {
           NSHTTPCookie * cookie = [self extractConnectCookie];
           if (cookie) {
               successBlock(task, JSON, cookie);
           }
           else {
               failureBlock(task, nil);
           }
           
       } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
           failureBlock(task, error);
       }];
}

-(BOOL) reloginWithUsername:(NSString*) username successBlock:(JSONCookieSuccessBlock) successBlock failureBlock: (JSONFailureBlock) failureBlock
{
    DDLogInfo(@"relogin: %@", username);
    //if we have password login again
    NSString * password = nil;
    
    if (username) {
        password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:username];
    }
    
    if (username && password) {
        dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        
        dispatch_async(q, ^{
            DDLogVerbose(@"getting identity");
            SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
            DDLogVerbose(@"got identity");
            
            if (!identity) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failureBlock(nil,nil);
                });
                return;
            }
            
            DDLogVerbose(@"creating signature");
            
            NSData * decodedSalt = [NSData dataFromBase64String: [identity salt]];
            NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: decodedSalt];
            NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
            
            NSData * signature = [EncryptionController signUsername:identity.username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
            NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
            NSString * signatureString = [signature SR_stringByBase64Encoding];
            
            DDLogInfo(@"logging in to server");
            [[NetworkController sharedInstance]
             loginWithUsername:identity.username
             andPassword:passwordString
             andSignature: signatureString
             successBlock:^(NSURLSessionTask *task, id JSON, NSHTTPCookie * cookie) {
                 DDLogVerbose(@"login response");
                 [[IdentityController sharedInstance] userLoggedInWithIdentity:identity password: password cookie: cookie reglogin:YES];
                 successBlock(task, JSON, cookie);
             }
             failureBlock: failureBlock];
        });
        
        return YES;
        
        
    }
    else {
        return NO;
    }
}

-(void) createUser3WithUsername:(NSString *)username derivedPassword:(NSString *)derivedPassword dhKey:(NSString *)encodedDHKey dsaKey:(NSString *)encodedDSAKey authSig:(NSString *)authSig clientSig:(NSString *)clientSig successBlock:(HTTPCookieSuccessBlock)successBlock failureBlock:(HTTPFailureBlock)failureBlock {
    
    [self clearCookies];
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   derivedPassword,@"password",
                                   authSig, @"authSig",
                                   encodedDHKey, @"dhPub",
                                   encodedDSAKey, @"dsaPub",
                                   versionString, @"version",
                                   clientSig, @"clientSig2",
                                   @"ios", @"platform", nil];
    
    [self addPurchaseReceiptToParams:params];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    [self POST:@"users3" parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSHTTPCookie * cookie = [self extractConnectCookie];
        if (cookie) {
            successBlock(task, responseObject, cookie);
        }
        else {
            failureBlock(task, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        failureBlock(task, error);
    }];
}


-(NSHTTPCookie *) extractConnectCookie {
    //save the cookie
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:_baseUrl]];
    
    for (NSHTTPCookie *cookie in cookies)
    {
        if ([cookie.name isEqualToString:@"connect.sid"]) {
            _loggedOut = NO;
            return cookie;
        }
    }
    
    return nil;
    
}

-(void) getFriendsSuccessBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    [self GET:@"friends" parameters:nil progress:nil success:successBlock failure:failureBlock];
}

-(void) inviteFriend: (NSString *) friendname successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat: @"invite/%@",friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    [self POST:path parameters:nil progress:nil success:successBlock failure:failureBlock];
    
}

- (void) getKeyVersionForUsername:(NSString *)username successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock
{
    NSString * path = [[NSString stringWithFormat: @"keyversion/%@",username] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    [self GET:path parameters:nil progress:nil success:successBlock failure:failureBlock];
    
}

- (void) getPublicKeys2ForUsername:(NSString *)username andVersion:(NSString *)version successBlock:(JSONSuccessBlock)successBlock failureBlock:(JSONFailureBlock) failureBlock{
    
    
    [self GET:[self buildPublicKeyPathForUsername:username version:version] parameters:nil progress:nil success:successBlock
      failure:failureBlock];
    
}

-(NSString *) buildPublicKeyPathForUsername: (NSString *) username version: (NSString *) version {
    NSString * path = [[NSString stringWithFormat: @"publickeys/%@/since/%@",username, version]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ;
    
    return path;
}

-(void) getMessageDataForUsername:(NSString *)username andMessageId:(NSInteger)messageId andControlId:(NSInteger) controlId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagedataopt/%@/%ld/%ld", username, (long)messageId, (long)controlId]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self GET: path parameters:nil progress:nil success:successBlock failure:failureBlock];
    
}

-(void) respondToInviteName:(NSString *) friendname action: (NSString *) action successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"invites/%@/%@", friendname, action] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self POST: path parameters:nil constructingBodyWithBlock:nil progress:nil success:successBlock failure:failureBlock];
    
}

-(void) getLatestDataSinceUserControlId: (NSInteger) latestUserControlId spotIds: (NSArray *) spotIds successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    NSMutableDictionary *params = nil;
    if ([spotIds count] > 0) {
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:spotIds options:0 error:nil];
        NSString * jsonString =[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        params = [NSMutableDictionary dictionaryWithObjectsAndKeys:jsonString,@"spotIds", nil];
    }
    DDLogVerbose(@"GetLatestData: params; %@", params);
    
    [self addPurchaseReceiptToParams:params];
    
    NSString * path = [NSString stringWithFormat:@"optdata/%ld", (long)latestUserControlId];
    [self POST:path parameters:params progress:nil success:successBlock failure:failureBlock];
    
    
}



-(void) logout {
    //send logout
    if (!_loggedOut) {
        DDLogInfo(@"logout");
        [self POST:@"logout" parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            [self deleteCookies];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [self deleteCookies];
        }];
    }
}

-(void) deleteCookies {
    //blow cookies away
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:_baseUrl]];
    for (NSHTTPCookie *cookie in cookies)
    {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage]  deleteCookie:cookie];
    }
    
}


-(void) deleteFriend:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"friends/%@", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self DELETE:path parameters:nil success:successBlock failure:failureBlock];
}


-(void) deleteMessageName:(NSString *) name serverId: (NSInteger) serverid successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messages/%@/%ld", name, (long)serverid] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self DELETE:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) deleteMessagesUTAI:(NSInteger) utaiId name: (NSString *) name successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagesutai/%@/%ld", name, (long)utaiId] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self DELETE:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) userExists: (NSString *) username successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"users/%@/exists", username] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self GET:path parameters:nil progress:nil success:successBlock failure:failureBlock];
}

-(void) getEarlierMessagesForUsername: (NSString *) username messageId: (NSInteger) messageId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagesopt/%@/before/%ld", username, (long)messageId]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self GET:path parameters:nil progress:nil success:successBlock failure:failureBlock];
}

-(void) validateUsername: (NSString *) username password: (NSString *) password signature: (NSString *) signature successBlock:(HTTPSuccessBlock) successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:username,@"username",password,@"password",signature,@"authSig", nil];
    [self POST:@"validate" parameters:params progress:nil success:successBlock failure:failureBlock];
}

-(void) postFileStreamData: (NSData *) data
                ourVersion: (NSString *) ourVersion
             theirUsername: (NSString *) theirUsername
              theirVersion: (NSString *) theirVersion
                    fileid: (NSString *) fileid
                  mimeType: (NSString *) mimeType
              successBlock: ( void (^)(id JSON)) successBlock
              failureBlock: ( void (^)(NSURLResponse * response, NSError * error)) failureBlock
{
    DDLogInfo(@"postFileStream, fileid: %@", fileid);
    
    NSString * encodedId = [self encodeBase64:fileid];
    DDLogInfo(@"postFileStream, encodedId: %@", encodedId);
    NSString * path = [NSString stringWithFormat:@"%@/files/%@/%@/%@/%@/%@",_baseUrl, ourVersion, [theirUsername stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], theirVersion, encodedId, ([mimeType isEqual:MIME_TYPE_M4A] ? @"mp4" : @"image")];
    DDLogInfo(@"postFileStream, path: %@", path);
    NSMutableURLRequest *request  = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    
    
    NSURLSessionUploadTask * task = [self uploadTaskWithRequest:request fromData:data progress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (error) {
            failureBlock(response, error);
        }
        else {
            successBlock(responseObject);
        }
    }];
    [task resume];
}

-(void) postFriendStreamData: (NSData *) data
                  ourVersion: (NSString *) ourVersion
               theirUsername: (NSString *) theirUsername
                          iv: (NSString *) iv
                successBlock: ( void (^)(id responseObject)) successBlock
                failureBlock: ( void (^)(NSURLResponse * response, NSError * error)) failureBlock
{
    NSString * encodedIv = [self encodeBase64:iv];
    
    DDLogInfo(@"postFriendFileStream, encoded iv: %@", encodedIv);
    
    NSString * path = [NSString stringWithFormat:@"%@/files/%@/%@/%@",_baseUrl, [theirUsername stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], ourVersion, encodedIv];
    NSMutableURLRequest *request  = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    
    
    NSURLSessionUploadTask * task = [self uploadTaskWithRequest:request fromData:data progress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (error) {
            failureBlock(response, error);
        }
        else {
            successBlock(responseObject);
        }
    }];
    [task resume];
}

-(void) setMessageShareable:(NSString *) name
                   serverId: (NSInteger) serverid
                  shareable: (BOOL) shareable
               successBlock:(HTTPSuccessBlock)successBlock
               failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:(shareable ? @YES : @NO),@"shareable", nil];
    NSString * path = [[NSString stringWithFormat:@"messages/%@/%ld/shareable", name, (long)serverid] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self PUT:path parameters:params success:successBlock failure:failureBlock];
    
}

-(void) getKeyTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                  successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock
{
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    [self POST:@"/keytoken" parameters:params progress:nil success:successBlock failure:failureBlock];
}


-(void) updateKeys3ForUsername:(NSString *) username
                      password:(NSString *) password
                   publicKeyDH:(NSString *) pkDH
                  publicKeyDSA:(NSString *) pkDSA
                       authSig:(NSString *) authSig
                      tokenSig:(NSString *) tokenSig
                    keyVersion:(NSString *) keyversion
                     clientSig:(NSString *) clientSig
                  successBlock:(HTTPSuccessBlock) successBlock
                  failureBlock:(HTTPFailureBlock) failureBlock
{
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   pkDH, @"dhPub",
                                   pkDSA, @"dsaPub",
                                   authSig, @"authSig",
                                   tokenSig, @"tokenSig",
                                   clientSig, @"clientSig2",
                                   keyversion, @"keyVersion",
                                   versionString, @"version",
                                   @"ios", @"platform", nil];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    
    [self POST:@"/keys3" parameters:params progress:nil success:successBlock failure:failureBlock];
    
    
}

-(void) getDeleteTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                     successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    [self POST:@"/deletetoken" parameters:params progress:nil success:successBlock failure:failureBlock];
}

-(void) deleteUsername:(NSString *) username
              password:(NSString *) password
               authSig:(NSString *) authSig
              tokenSig:(NSString *) tokenSig
            keyVersion:(NSString *) keyversion
          successBlock:(HTTPSuccessBlock) successBlock
          failureBlock:(HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   authSig, @"authSig",
                                   tokenSig, @"tokenSig",
                                   keyversion, @"keyVersion",
                                   nil];
    
    [self POST:@"/users/delete" parameters:params progress:nil success:successBlock failure:failureBlock];
}


-(void) getPasswordTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                       successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    [self POST:@"/passwordtoken" parameters:params progress:nil success:successBlock failure:failureBlock];
    
}

-(void) changePasswordForUsername:(NSString *) username
                      oldPassword:(NSString *) password
                      newPassword:(NSString *) newPassword
                          authSig:(NSString *) authSig
                         tokenSig:(NSString *) tokenSig
                       keyVersion:(NSString *) keyversion
                     successBlock:(HTTPSuccessBlock) successBlock
                     failureBlock:(HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   authSig, @"authSig",
                                   tokenSig, @"tokenSig",
                                   keyversion, @"keyVersion",
                                   newPassword, @"newPassword",
                                   nil];
    
    [self PUT:@"/users/password" parameters:params success:successBlock failure:failureBlock];
    
}

-(void) deleteFromCache: (NSURLRequest *) request {
    [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
}

-(void) getShortUrl:(NSString*) longUrl callback: (CallbackBlock) callback
{
    NSString * path = [[NSString stringWithFormat:@"https://api-ssl.bitly.com/v3/shorten?access_token=%@&longUrl=%@", BITLY_TOKEN, longUrl] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableURLRequest *request = [[AFJSONRequestSerializer serializer] requestWithMethod:@"GET" URLString:path parameters:nil error:nil];
    NSURLSessionDataTask * task = [self dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if  (responseObject) {
            callback([responseObject valueForKeyPath:@"data.url"]);
        }
        else
        {
            callback(longUrl);
        }
    }];
    [task resume];
}

-(void) addPurchaseReceiptToParams: (NSMutableDictionary *) params {
    NSString * purchaseReceipt = nil;
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        purchaseReceipt = [[NSUserDefaults standardUserDefaults] objectForKey:@"appStoreReceipt"];
    } else {
        purchaseReceipt =  [[NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL] ] base64EncodedStringWithOptions:0];
    }
    
    if (purchaseReceipt) {
        [params setObject: purchaseReceipt forKey:@"purchaseReceipt"];
    }
}

-(void) assignFriendAlias:(NSString *) data friendname: (NSString *) friendname version: (NSString *) version iv: (NSString *) iv successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   data, @"data",
                                   iv,@"iv",
                                   version,@"version",
                                   nil];
    
    NSString * path = [[NSString stringWithFormat:@"users/%@/alias2", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    [self PUT:path parameters:params success:successBlock failure:failureBlock];
}

-(void) deleteFriendAlias:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"users/%@/alias", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self DELETE:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) deleteFriendImage:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"users/%@/image", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self DELETE:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) updateSigs: (NSDictionary *) sigs {
    NSString * path = [NSString stringWithFormat:@"%@/sigs2",_baseUrl];
    NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:sigs, @"sigs2", nil];
    NSMutableURLRequest * req = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST" URLString:path parameters:params error:nil];
    NSURLSessionDataTask * task = [self dataTaskWithRequest:req completionHandler:nil];
    [task resume];
}

-(void) sendMessages:(NSArray *)messages successBlock:(JSONSuccessBlock)successBlock failureBlock:(JSONFailureBlock)failureBlock {
    NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:messages, @"messages", nil];
    [self POST:@"messages" parameters:params progress:nil success:successBlock failure:failureBlock];
    
}

-(NSString *) encodeBase64: (NSString *) base64 {
    NSString * encodedString = [base64 stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    return encodedString;
}
@end
