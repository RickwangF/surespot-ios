/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MessageView+NSURLCache.h"
#import "objc/runtime.h"
#import "MessageView.h"
#import "UIUtils.h"
#import "CocoaLumberjack.h"
#import "NSBundle+FallbackLanguage.h"
#import "DownloadGifOperation.h"
#import "SurespotAppDelegate.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

static char operationKey;


@implementation MessageView (NSURLCache)



- (void)setMessage:(SurespotMessage *) message
       ourUsername:(NSString *) ourUsername
          callback:(CallbackBlock)callback
      retryAttempt:(NSInteger) retryAttempt
{
    
    
    __weak MessageView *wself = self;
    
    
    [self cancelCurrentImageLoad];
    DownloadGifOperation * operation = [[DownloadGifOperation alloc] initWithMessage:message callback:^(id data) {
        
        // if (!wself) return;
        //      dispatch_main_async_safe(^
        //      {
        if (!wself) return;
        
        //do nothing if the message has changed
        if (![wself.message isEqual:message]) {
            DDLogVerbose(@"cell is pointing to a different message now, not assigning gif data");
            return;
        }
        if (data)
        {
            FLAnimatedImage * image = [FLAnimatedImage animatedImageWithGIFData:data];
            if (image) {
                wself.gifView.animatedImage = image;
                
                
                if ([image size].height > [image size].width) {
                    [wself.gifView setContentMode:UIViewContentModeScaleAspectFit];
                }
                else {
                    [wself.gifView setContentMode:UIViewContentModeScaleAspectFill];
                }
            }
            if (message.formattedDate) {
                wself.messageStatusLabel.text = message.formattedDate;
            }
        }
        else {
            //retry
            if (retryAttempt < RETRY_ATTEMPTS) {
                double timerInterval = [UIUtils generateIntervalK: retryAttempt maxInterval: RETRY_DELAY];
                DDLogInfo(@"no data downloaded, retrying attempt: %ld, in %f seconds", (long)retryAttempt+1, timerInterval);
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timerInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self setMessage:message ourUsername: ourUsername  callback:callback retryAttempt:retryAttempt+1];
                });
                
                return;
            }
            else {
                wself.messageStatusLabel.text = NSLocalizedString(@"error_downloading_message_data", nil);
            }
        }
        
        [wself setNeedsLayout];
        if (callback )
        {
            callback(data);
        }
        //    });
    }];
    
    objc_setAssociatedObject(self, &operationKey, operation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [SurespotAppDelegate.operationQueue addOperation:operation];
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
