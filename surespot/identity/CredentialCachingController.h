//
//  CredentialCachingController.h
//  surespot
//
//  Created by Adam on 8/5/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EncryptionController.h"
#import "PublicKeys.h"
#import "SurespotConstants.h"

@interface CredentialCachingController : NSObject
+(CredentialCachingController*)sharedInstance;


@property (nonatomic, retain) NSMutableDictionary * sharedSecretsDict;
@property (nonatomic, retain) NSMutableDictionary * publicKeysDict;
@property (nonatomic, strong) NSMutableDictionary * latestVersionsDict;


@property (nonatomic, strong) NSOperationQueue * genSecretQueue;
@property (nonatomic, strong) NSOperationQueue * publicKeyQueue;
@property (atomic, strong) NSString * activeUsername;


-(void) getSharedSecretForOurUsername: (NSString *) ourUsername ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion hashed: (BOOL) hashed callback: (CallbackBlock) callback;
-(void) loginIdentity: (SurespotIdentity *) identity password: (NSString *) password cookie: (NSHTTPCookie *) cookie isActive: (BOOL) isActive;
-(void) clearUserData: (NSString *) theirUsername;

-(void) getLatestVersionForOurUsername: (NSString *) ourUsername  theirUsername: (NSString *) theirUsername callback:(CallbackStringBlock) callback;
-(void) updateLatestVersionForUsername: (NSString *) username version: (NSString *) version;

-(void) logout;
-(void) clearIdentityData:(NSString *) username;
-(void) cacheSharedSecret: secret forKey: sharedSecretKey;
-(void) saveLatestVersions;
-(void) updateIdentity: (SurespotIdentity *) identity onlyIfExists: (BOOL) onlyIfExists;
-(SurespotIdentity *) getIdentityForUsername: (NSString *) username password: (NSString *) password;
-(SurespotIdentity *) getLoggedInIdentity;
-(NSHTTPCookie *) getCookieForUsername: (NSString *) username;
-(BOOL) setSessionForUsername: (NSString *) username;
@end
