

#import "MessageView.h"
#import "SurespotMessage.h"
#import "SurespotConstants.h"

@interface MessageView (GifCache)

- (void)setMessage:(SurespotMessage *) message
       ourUsername:(NSString *) ourUsername
          callback:(CallbackBlock)callback
      retryAttempt:(NSInteger) retryAttempt;

- (void)cancelCurrentImageLoad;
@end
