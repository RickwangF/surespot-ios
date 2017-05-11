//
//  SharedCacheAndQueueManager.m
//  surespot
//
//  Created by Adam on 5/11/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharedCacheAndQueueManager.h"

@implementation SharedCacheAndQueueManager

+(SharedCacheAndQueueManager *) sharedInstance {
    static SharedCacheAndQueueManager *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

-(SharedCacheAndQueueManager *) init {
    self = [super init];
    
    if (self) {
        self.downloadQueue = [NSOperationQueue new];
        self.gifCache = [[NSCache alloc] init];

    }
    
    return self;
}
@end
