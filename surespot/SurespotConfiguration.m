//
//  SurespotConfiguration.m
//  surespot
//
//  Created by Adam on 4/9/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotConfiguration.h"

@interface SurespotConfiguration() {}

@end
@implementation SurespotConfiguration

+(SurespotConfiguration *) sharedInstance {
    static SurespotConfiguration *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

-(SurespotConfiguration *) init {
    self = [super init];
    
    if (self) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"configuration" ofType:@"plist"];
        NSDictionary *config = [[NSDictionary alloc] initWithContentsOfFile:path];
       
        _baseUrl = [config objectForKey:@"base_url"];
        _GOOGLE_CLIENT_ID = [config objectForKey:@"google_client_id"];
        _GOOGLE_CLIENT_SECRET = [config objectForKey:@"google_client_secret"];
        _BITLY_TOKEN = [config objectForKey:@"bitly_token"];
                _GIPHY_API_KEY = [config objectForKey:@"giphy_api_key"];
    }
    
    return self;
}

@end
