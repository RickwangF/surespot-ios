//
//  NetworkManager.h
//  surespot
//
//  Created by Adam on 4/2/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#ifndef NetworkManager_h
#define NetworkManager_h

#import "NetworkController.h"

@interface NetworkManager : NSObject
+(NetworkManager *) sharedInstance;
-(NetworkController *) getNetworkController: (NSString *) username;
@end



#endif /* NetworkManager_h */
