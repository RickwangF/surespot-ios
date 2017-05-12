//
//  GifSearchView+GifCache.m
//  surespot
//
//  Created by Adam on 5/11/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import "GifSearchView+GifCache.h"
#import "objc/runtime.h"
#import "GifSearchView.h"
#import "UIUtils.h"
#import "CocoaLumberjack.h"
#import "NSBundle+FallbackLanguage.h"
#import "DownloadGifOperation.h"
#import "SharedCacheAndQueueManager.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

static char operationKey;

@interface GifSearchView ()
@end

@implementation GifSearchView (GifCache)



- (void)setUrl:(NSString *) url
  retryAttempt:(NSInteger) retryAttempt
{
    
    __weak GifSearchView *wself = self;
    [self cancelCurrentImageLoad];
    
    //do nothing if the message has changed
    if (![wself.url isEqual:url]) {
        DDLogVerbose(@"cell is pointing to a different url now, not assigning gif data");
        return;
    }
    
    //See if it's already loaded
    __block FLAnimatedImage * image = [[[SharedCacheAndQueueManager sharedInstance] gifCache] objectForKey:url];
    if (!wself) return;
    if (image) {
        //            [UIView transitionWithView:wself.imageView
        //                              duration:1.0f
        //                               options:UIViewAnimationOptionTransitionCrossDissolve
        //                            animations:^{
        wself.gifView.animatedImage = image;
        // } completion:nil];
        
        return;
        
    }
    
    
    
    DownloadGifOperation * operation = [[DownloadGifOperation alloc] initWithUrlString:url callback:^(id data) {
        if (!wself) return;
        if (data)
        {
            image = [FLAnimatedImage animatedImageWithGIFData:data];
            if (!wself) return;
            if (image) {
                //                    [UIView transitionWithView:wself.imageView
                //                                      duration:1.0f
                //                                       options:UIViewAnimationOptionTransitionCrossDissolve
                //                                    animations:^{
                wself.gifView.animatedImage = image;
                //                                    } completion:nil];
         
                [[[SharedCacheAndQueueManager sharedInstance] gifCache] setObject:image forKey:url];
            }
            
        }
        else {
            //retry
            if (retryAttempt < RETRY_ATTEMPTS) {
                [self scheduleRetryUrl:url retryAttempt:retryAttempt maxInterval:RETRY_DELAY];
                return;
            }
        }
    }];
    
    objc_setAssociatedObject(self, &operationKey, operation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[[SharedCacheAndQueueManager sharedInstance] downloadQueue] addOperation:operation];

}



-(void) scheduleRetryUrl:(NSString *) url
            retryAttempt:(NSInteger) retryAttempt
             maxInterval:(double) maxInterval {
    double timerInterval = [UIUtils generateIntervalK: retryAttempt maxInterval: maxInterval];
    DDLogInfo(@"no data downloaded, retrying attempt: %ld, in %f seconds", (long)retryAttempt+1, timerInterval);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timerInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setUrl:url retryAttempt:retryAttempt+1];
    });
    
}


- (void)cancelCurrentImageLoad
{
    // Cancel in progress downloader from queue
    DownloadGifOperation * operation = objc_getAssociatedObject(self, &operationKey);
    if (operation)
    {
        [operation cancel];
        objc_setAssociatedObject(self, &operationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}


@end
