//
//  SurespotConfiguration.h
//  surespot
//
//  Created by Adam on 4/9/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#ifndef SurespotConfiguration_h
#define SurespotConfiguration_h

@interface SurespotConfiguration : NSObject
+(SurespotConfiguration *) sharedInstance;
@property (strong, nonatomic, readonly) NSString *baseUrl;
@property (strong, nonatomic, readonly) NSString *GOOGLE_CLIENT_ID;
@property (strong, nonatomic, readonly) NSString *GOOGLE_CLIENT_SECRET;
@property (strong, nonatomic, readonly) NSString *BITLY_TOKEN;
@end

#endif /* SurespotConfiguration_h */
