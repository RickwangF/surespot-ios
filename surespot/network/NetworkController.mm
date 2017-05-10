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
#import "CocoaLumberjack.h"
#import "NSData+Base64.h"
#import "NSData+SRB64Additions.h"
#import "EncryptionController.h"
#import "CredentialCachingController.h"
#import "NetworkManager.h"
#import "SurespotConfiguration.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface NetworkController()
@property (nonatomic, strong) NSString * baseUrl;
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSHTTPCookie * cookie;
@end
@implementation NetworkController


-(NetworkController*)init: (NSString *) username
{
    NSURLSessionConfiguration * sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    self = [super initWithBaseURL:[NSURL URLWithString: [[SurespotConfiguration sharedInstance] baseUrl]] sessionConfiguration:sessionConfiguration];
    
    if (self != nil) {
        _baseUrl = [[SurespotConfiguration sharedInstance] baseUrl];
        _username = username;
        
        [self.requestSerializer setValue:[NSString stringWithFormat:@"%@/%@ (%@; CPU iPhone OS 7_0_4; Scale/%0.2f)", [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleExecutableKey] ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleIdentifierKey], (__bridge id)CFBundleGetValueForInfoDictionaryKey(CFBundleGetMainBundle(), kCFBundleVersionKey) ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f)] forHTTPHeaderField:@"User-Agent"];
        
        self.responseSerializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:@[[AFJSONResponseSerializer serializer],
                                                                                                            [AFHTTPResponseSerializer serializer]]];
        self.requestSerializer = [AFJSONRequestSerializer serializer];
        
        //#ifdef DEBUG
        //        //allow invalid certs for dev
        //        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        //        securityPolicy.allowInvalidCertificates = YES;
        //        securityPolicy.validatesDomainName = NO;
        //        self.securityPolicy = securityPolicy;
        //#endif
    }
    
    return self;
}

#pragma mark - reauth

- (NSURLSessionDataTask *)reauthGET:(NSString *)URLString
                         parameters:(id)parameters
                            success:(void (^)(NSURLSessionDataTask * _Nonnull, id _Nullable))success
                            failure:(void (^)(NSURLSessionDataTask * _Nullable, NSError * _Nonnull))failure
{
    return [self GET:URLString
          parameters:parameters
            progress:nil
             success:success
             failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                 if ([(NSHTTPURLResponse *)[task response] statusCode] == 401) {
                     [self reloginSuccessBlock:^(NSURLSessionTask *task2, id responseObject) {
                         //relogin success, call original method
                         DDLogDebug(@"reauth Success");
                         [self reauthGET:URLString parameters:parameters success:success failure:failure];
                     } failureBlock:^(NSURLSessionTask *task2, NSError *error2) {
                         //relogin failed, call fail block  with original task and error
                         failure(task, error);
                         if (!task2 || [(NSHTTPURLResponse *)[task2 response] statusCode] == 401) {
                             DDLogDebug(@"reauth failure");
                             [self setUnauthorized];
                         }
                         
                     }];
                 }
                 else {
                     failure(task, error);
                 }
             }];
}


- (NSURLSessionDataTask *)reauthPOST:(NSString *)URLString
                          parameters:(id)parameters
                             success:(void (^)(NSURLSessionDataTask * _Nonnull, id _Nullable))success
                             failure:(void (^)(NSURLSessionDataTask * _Nullable, NSError * _Nonnull))failure
{
    return [self POST:URLString parameters:parameters progress:nil success:success failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if ([(NSHTTPURLResponse *)[task response] statusCode] == 401) {
            [self reloginSuccessBlock:^(NSURLSessionTask *task2, id responseObject) {
                //relogin success, call original method
                [self reauthPOST:URLString parameters:parameters success:success failure:failure];
            } failureBlock:^(NSURLSessionTask *task2, NSError *error2) {
                //relogin failed, call fail block  with original task and error
                failure(task, error);
                if (!task2 || [(NSHTTPURLResponse *)[task2 response] statusCode] == 401) {
                    [self setUnauthorized];
                }
            }];
        }
        else {
            failure(task, error);
        }
        
    }];
}

- (NSURLSessionDataTask *)reauthDELETE:(NSString *)URLString
                            parameters:(id)parameters
                               success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                               failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    return [self DELETE:URLString parameters:parameters success:success failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if ([(NSHTTPURLResponse *)[task response] statusCode] == 401) {
            [self reloginSuccessBlock:^(NSURLSessionTask *task2, id responseObject) {
                //relogin success, call original method
                [self reauthDELETE:URLString parameters:parameters success:success failure:failure];
            } failureBlock:^(NSURLSessionTask *task2, NSError *error2) {
                //relogin failed, call fail block  with original task and error
                failure(task, error);
                if (!task2 || [(NSHTTPURLResponse *)[task2 response] statusCode] == 401) {
                    [self setUnauthorized];
                }
            }];
        }
        else {
            failure(task, error);
        }
        
    }];
}

- (NSURLSessionDataTask *)reauthPUT:(NSString *)URLString
                         parameters:(id)parameters
                            success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                            failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    return [self PUT:URLString parameters:parameters success:success failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if ([(NSHTTPURLResponse *)[task response] statusCode] == 401) {
            [self reloginSuccessBlock:^(NSURLSessionTask *task2, id responseObject) {
                //relogin success, call original method
                [self reauthPUT:URLString parameters:parameters success:success failure:failure];
            } failureBlock:^(NSURLSessionTask *task2, NSError *error2) {
                //relogin failed, call fail block  with original task and error
                failure(task, error);
                if (!task2 || [(NSHTTPURLResponse *)[task2 response] statusCode] == 401) {
                    [self setUnauthorized];
                }
            }];
        }
        else {
            failure(task, error);
        }
        
    }];
}

#pragma mark - non reauth'd methods

-(void) loginWithUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
             successBlock:(HTTPCookieSuccessBlock) successBlock failureBlock: (HTTPFailureBlock) failureBlock
{
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   versionString, @"version",
                                   @"ios", @"platform", nil];
    
    // [self addPurchaseReceiptToParams:params];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    
    [self clearCookie];
    
    [self POST:@"login"
    parameters:params
      progress:nil
       success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable JSON) {
           NSHTTPCookie * cookie = [self extractConnectCookie];
           if (cookie) {
               [self setCookie:cookie];
               successBlock(task, JSON, cookie);
           }
           else {
               failureBlock(task, nil);
           }
           
       } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
           failureBlock(task, error);
       }];
}

-(BOOL) reloginSuccessBlock:(HTTPSuccessBlock) successBlock failureBlock: (HTTPFailureBlock) failureBlock
{
    DDLogInfo(@"%@: relogin", _username);
    //if we have password login again
    NSString * password = nil;
    
    if (_username) {
        password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:_username];
    }
    
    if (_username && password) {
        dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        
        dispatch_async(q, ^{
            DDLogVerbose(@"getting identity");
            SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:_username andPassword:password];
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
            //use nil controller otherwise the request seems to block if we use the same network controller that is trying to auth the request to auth the request
            [[[NetworkManager sharedInstance] getNetworkController:nil] loginWithUsername:identity.username
                                                                              andPassword:passwordString
                                                                             andSignature: signatureString
                                                                             successBlock:^(NSURLSessionTask *task, id JSON, NSHTTPCookie * cookie) {
                                                                                 DDLogVerbose(@"login response");
                                                                                 
                                                                                 [self setCookie:cookie];
                                                                                 [[IdentityController sharedInstance] userLoggedInWithIdentity:identity password: password cookie: cookie relogin:YES];
                                                                                 successBlock(task, JSON);
                                                                             }
                                                                             failureBlock: failureBlock];
        });
        
        return YES;
        
        
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            failureBlock(nil,nil);
        });
        
        return NO;
    }
}

-(void) createUser3WithUsername:(NSString *)username derivedPassword:(NSString *)derivedPassword dhKey:(NSString *)encodedDHKey dsaKey:(NSString *)encodedDSAKey authSig:(NSString *)authSig clientSig:(NSString *)clientSig successBlock:(HTTPCookieSuccessBlock)successBlock failureBlock:(HTTPFailureBlock)failureBlock {
    
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
    
    [self clearCookie];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    [self POST:@"users3" parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSHTTPCookie * cookie = [self extractConnectCookie];
        if (cookie) {
            //set cookie in network controller for the user we just created
            [[[NetworkManager sharedInstance] getNetworkController:username] setCookie:cookie];
            successBlock(task, responseObject, cookie);
        }
        else {
            failureBlock(task, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        failureBlock(task, error);
    }];
}

-(void) logout {
    //send logout
    DDLogInfo(@"logout");
    [self POST:@"logout" parameters:nil progress:nil success:nil failure:nil];
    [self clearCookie];
}


#pragma mark reauth'd methods


-(void) getFriendsSuccessBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    [self reauthGET:@"friends" parameters:nil success:successBlock failure:failureBlock];
}

-(void) inviteFriend: (NSString *) friendname successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat: @"invite/%@",friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthPOST:path parameters:nil success:successBlock failure:failureBlock];
}

- (void) getKeyVersionForUsername:(NSString *)username successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock
{
    NSString * path = [[NSString stringWithFormat: @"keyversion/%@",username] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthGET:path parameters:nil success:successBlock failure:failureBlock];
}

- (void) getPublicKeys2ForUsername:(NSString *)username andVersion:(NSString *)version successBlock:(HTTPSuccessBlock)successBlock failureBlock:(HTTPFailureBlock) failureBlock{
    [self reauthGET:[self buildPublicKeyPathForUsername:username version:version] parameters:nil success:successBlock failure:failureBlock];
}

-(void) getMessageDataForUsername:(NSString *)username andMessageId:(NSInteger)messageId andControlId:(NSInteger) controlId successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagedataopt/%@/%ld/%ld", username, (long)messageId, (long)controlId]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthGET: path parameters:nil success:successBlock failure:failureBlock];
}

-(void) respondToInviteName:(NSString *) friendname action: (NSString *) action successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"invites/%@/%@", friendname, action] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthPOST:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) getLatestDataSinceUserControlId: (NSInteger) latestUserControlId spotIds: (NSArray *) spotIds successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = nil;
    if ([spotIds count] > 0) {
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:spotIds options:0 error:nil];
        NSString * jsonString =[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        params = [NSMutableDictionary dictionaryWithObjectsAndKeys:jsonString,@"spotIds", nil];
    }
    DDLogVerbose(@"GetLatestData: params; %@", params);
    
    [self addPurchaseReceiptToParams:params];
    
    NSString * path = [NSString stringWithFormat:@"optdata/%ld", (long)latestUserControlId];
    [self reauthPOST:path parameters:params success:successBlock failure:failureBlock];
}

-(void) deleteFriend:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"friends/%@", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthDELETE:path parameters:nil success:successBlock failure:failureBlock];
}


-(void) deleteMessageName:(NSString *) name serverId: (NSInteger) serverid successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messages/%@/%ld", name, (long)serverid] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthDELETE:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) deleteMessagesUTAI:(NSInteger) utaiId name: (NSString *) name successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagesutai/%@/%ld", name, (long)utaiId] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthDELETE:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) userExists: (NSString *) username successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"users/%@/exists", username] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthGET:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) getEarlierMessagesForUsername: (NSString *) username messageId: (NSInteger) messageId successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagesopt/%@/before/%ld", username, (long)messageId]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthGET:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) validateUsername: (NSString *) username password: (NSString *) password signature: (NSString *) signature successBlock:(HTTPSuccessBlock) successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:username,@"username",password,@"password",signature,@"authSig", nil];
    [self reauthPOST:@"validate" parameters:params success:successBlock failure:failureBlock];
}

-(void) setMessageShareable:(NSString *) name
                   serverId: (NSInteger) serverid
                  shareable: (BOOL) shareable
               successBlock:(HTTPSuccessBlock)successBlock
               failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:(shareable ? @YES : @NO),@"shareable", nil];
    NSString * path = [[NSString stringWithFormat:@"messages/%@/%ld/shareable", name, (long)serverid] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthPUT:path parameters:params success:successBlock failure:failureBlock];
    
}

-(void) getKeyTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                  successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock
{
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    [self reauthPOST:@"/keytoken" parameters:params success:successBlock failure:failureBlock];
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
    
    [self reauthPOST:@"/keys3" parameters:params success:successBlock failure:failureBlock];
    
    
}

-(void) getDeleteTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                     successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    [self reauthPOST:@"/deletetoken" parameters:params success:successBlock failure:failureBlock];
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
    
    [self reauthPOST:@"/users/delete" parameters:params success:successBlock failure:failureBlock];
}


-(void) getPasswordTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                       successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    [self reauthPOST:@"/passwordtoken" parameters:params success:successBlock failure:failureBlock];
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
    
    [self reauthPUT:@"/users/password" parameters:params success:successBlock failure:failureBlock];
}

-(void) assignFriendAlias:(NSString *) data friendname: (NSString *) friendname version: (NSString *) version iv: (NSString *) iv successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   data, @"data",
                                   iv,@"iv",
                                   version,@"version",
                                   nil];
    
    NSString * path = [[NSString stringWithFormat:@"users/%@/alias2", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthPUT:path parameters:params success:successBlock failure:failureBlock];
}

-(void) deleteFriendAlias:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"users/%@/alias", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthDELETE:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) deleteFriendImage:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"users/%@/image", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reauthDELETE:path parameters:nil success:successBlock failure:failureBlock];
}

-(void) sendMessages:(NSArray *)messages successBlock:(HTTPSuccessBlock)successBlock failureBlock:(HTTPFailureBlock)failureBlock {
    NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:messages, @"messages", nil];
    [self reauthPOST:@"messages" parameters:params success:successBlock failure:failureBlock];
    
}

-(void) updateSigs: (NSDictionary *) sigs {
    NSString * path = [NSString stringWithFormat:@"%@/sigs2",_baseUrl];
    NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:sigs, @"sigs2", nil];
    [self reauthPOST:path parameters:params success:nil failure:nil];
}

#pragma mark streaming methods


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
    if (_cookie) {
        [request setValue:[NSString stringWithFormat:@"%@=%@",_cookie.name,_cookie.value] forHTTPHeaderField:@"Cookie"];
    }
    
    NSURLSessionUploadTask * task = [self uploadTaskWithRequest:request fromData:data progress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (error) {
            //reauth on 401
            long statusCode = [(NSHTTPURLResponse *) response statusCode];
            if (statusCode == 401) {
                [self reloginSuccessBlock:^(NSURLSessionTask *task, id responseObject) {
                    [self postFileStreamData:data
                                  ourVersion:ourVersion
                               theirUsername:theirUsername
                                theirVersion:theirVersion
                                      fileid:fileid
                                    mimeType:mimeType
                                successBlock:successBlock
                                failureBlock:failureBlock];
                }
                             failureBlock:^(NSURLSessionTask *task2, NSError *error2) {
                                 failureBlock(response, error);
                                 if (!task2 || [(NSHTTPURLResponse *)[task2 response] statusCode] == 401) {
                                     [self setUnauthorized];
                                 }
                             }];
            }
            else {
                failureBlock(response, error);
            }
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
    if (_cookie) {
        [request setValue:[NSString stringWithFormat:@"%@=%@",_cookie.name,_cookie.value] forHTTPHeaderField:@"Cookie"];
    }
    
    NSURLSessionUploadTask * task = [self uploadTaskWithRequest:request fromData:data progress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (error) {
            //reauth on 401
            long statusCode = [(NSHTTPURLResponse *) response statusCode];
            if (statusCode == 401) {
                [self reloginSuccessBlock:^(NSURLSessionTask *task, id responseObject) {
                    [self postFriendStreamData:data
                                    ourVersion:ourVersion
                                 theirUsername:theirUsername
                                            iv:iv
                                  successBlock:successBlock
                                  failureBlock:failureBlock];
                }
                             failureBlock:^(NSURLSessionTask *task2, NSError *error2) {
                                 failureBlock(response, error);
                                 if (!task2 || [(NSHTTPURLResponse *)[task2 response] statusCode] == 401) {
                                     [self setUnauthorized];
                                 }
                             }];
            }
            else {
                failureBlock(response, error);
            }
        }
        else {
            successBlock(responseObject);
        }
    }];
    [task resume];
}


#pragma mark external urls

-(void) getShortUrl:(NSString*) longUrl callback: (CallbackBlock) callback
{
    NSString * path = [[NSString stringWithFormat:@"https://api-ssl.bitly.com/v3/shorten?access_token=%@&longUrl=%@", [[SurespotConfiguration sharedInstance] BITLY_TOKEN], longUrl] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
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

#pragma mark helper methods

-(void) setUnauthorized {
    [self clearCookie];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"unauthorized" object:nil userInfo:[NSDictionary dictionaryWithObject:_username forKey:@"username"]];
}

-(NSHTTPCookie *) extractConnectCookie {
    //save the cookie
    NSArray *cookies = [[[[self session]configuration ] HTTPCookieStorage] cookiesForURL:[NSURL URLWithString:_baseUrl]];
    
    for (NSHTTPCookie *cookie in cookies)
    {
        if ([cookie.name isEqualToString:@"connect.sid"]) {
            return cookie;
        }
    }
    
    return nil;
}

-(void) clearCookie {
    _cookie = nil;
    [[self requestSerializer] setValue:nil forHTTPHeaderField:@"Cookie"];
}

-(void) setCookie: (NSHTTPCookie *) cookie {
    if (cookie && _username) {
        DDLogDebug(@"%@: setCookie: %@",_username, cookie);
        _cookie = cookie;
        [[self requestSerializer] setValue:[NSString stringWithFormat:@"%@=%@",cookie.name,cookie.value] forHTTPHeaderField:@"Cookie"];
    }
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

-(void) deleteFromCache: (NSURLRequest *) request {
    [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
}

-(NSString *) buildPublicKeyPathForUsername: (NSString *) username version: (NSString *) version {
    NSString * path = [[NSString stringWithFormat: @"publickeys/%@/since/%@",username, version]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ;
    return path;
}

-(NSString *) encodeBase64: (NSString *) base64 {
    NSString * encodedString = [base64 stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    return encodedString;
}
@end
