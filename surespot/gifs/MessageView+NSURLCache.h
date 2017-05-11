

#import "MessageView.h"
#import "SurespotMessage.h"
#import "SurespotConstants.h"

@interface MessageView (NSURLCache)

- (void)setMessage:(SurespotMessage *) message
       ourUsername:(NSString *) ourUsername
          callback:(CallbackBlock)callback
      retryAttempt:(NSInteger) retryAttempt;

- (void)cancelCurrentImageLoad;
@end
