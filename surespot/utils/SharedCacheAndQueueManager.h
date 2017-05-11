//
//  SharedCacheAndQueueManager.h
//  surespot
//
//  Created by Adam on 5/11/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#ifndef SharedCacheAndQueueManager_h
#define SharedCacheAndQueueManager_h



@interface SharedCacheAndQueueManager : NSObject
+(SharedCacheAndQueueManager *) sharedInstance;
@property (strong, nonatomic) NSOperationQueue * downloadQueue;
@property (strong, nonatomic) NSCache * gifCache;
@end



#endif /* SharedCacheAndQueueManager_h */
