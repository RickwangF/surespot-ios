/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MessageView+GifCache.h"
#import "objc/runtime.h"
#import "MessageView.h"
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

@interface MessageView ()
@end

@implementation MessageView (GifCache)



- (void)setMessage:(SurespotMessage *) message
       ourUsername:(NSString *) ourUsername
          callback:(CallbackBlock)callback
      retryAttempt:(NSInteger) retryAttempt
{
    if (!message.plainData) {
        if (retryAttempt < RETRY_ATTEMPTS) {
            [self scheduleRetryMessage:message ourUsername:ourUsername callback:callback retryAttempt:retryAttempt maxInterval:1];
        }
    }
    else {
        __weak MessageView *wself = self;
        [self cancelCurrentImageLoad];
        
        //do nothing if the message has changed
        if (![wself.message isEqual:message]) {
            DDLogVerbose(@"cell is pointing to a different message now, not assigning gif data");
            return;
        }
        
        if (message.formattedDate) {
            wself.messageStatusLabel.text = message.formattedDate;
        }
        
        //See if it's already loaded
        __block FLAnimatedImage * image = [[[SharedCacheAndQueueManager sharedInstance] gifCache] objectForKey:message.plainData];
        if (!wself) return;
        if (image) {
//            [UIView transitionWithView:wself.imageView
//                              duration:1.0f
//                               options:UIViewAnimationOptionTransitionCrossDissolve
//                            animations:^{
                                wself.gifView.animatedImage = image;
                           // } completion:nil];
            
            
            
            if ([image size].height > [image size].width) {
                [wself.gifView setContentMode:UIViewContentModeScaleAspectFit];
            }
            else {
                [wself.gifView setContentMode:UIViewContentModeScaleAspectFill];
            }
            return;
            
        }
        
        
        
        DownloadGifOperation * operation = [[DownloadGifOperation alloc] initWithMessage:message callback:^(id data) {
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
                    
                    
                    
                    if ([image size].height > [image size].width) {
                        [wself.gifView setContentMode:UIViewContentModeScaleAspectFit];
                    }
                    else {
                        [wself.gifView setContentMode:UIViewContentModeScaleAspectFill];
                    }
                    [[[SharedCacheAndQueueManager sharedInstance] gifCache] setObject:image forKey:message.plainData];
                }
                if (message.formattedDate) {
                    wself.messageStatusLabel.text = message.formattedDate;
                }
            }
            else {
                //retry
                if (retryAttempt < RETRY_ATTEMPTS) {
                    [self scheduleRetryMessage:message ourUsername:ourUsername callback:callback retryAttempt:retryAttempt maxInterval:RETRY_DELAY];
                    return;
                }
                else {
                    wself.messageStatusLabel.text = NSLocalizedString(@"error_downloading_message_data", nil);
                }
            }
            
            
            //[wself setNeedsLayout];
        }];
        
        objc_setAssociatedObject(self, &operationKey, operation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[[SharedCacheAndQueueManager sharedInstance] downloadQueue] addOperation:operation];
    }
}

-(void) scheduleRetryMessage:(SurespotMessage *) message
                 ourUsername:(NSString *) ourUsername
                    callback:(CallbackBlock)callback
                retryAttempt:(NSInteger) retryAttempt
                 maxInterval:(double) maxInterval {
    double timerInterval = [UIUtils generateIntervalK: retryAttempt maxInterval: maxInterval];
    DDLogInfo(@"no data downloaded, retrying attempt: %ld, in %f seconds", (long)retryAttempt+1, timerInterval);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timerInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setMessage:message ourUsername: ourUsername  callback:callback retryAttempt:retryAttempt+1];
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
