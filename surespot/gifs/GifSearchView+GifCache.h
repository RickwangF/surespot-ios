

#import "GifSearchView.h"
#import "SurespotMessage.h"
#import "SurespotConstants.h"

@interface GifSearchView (GifCache)

- (void)setUrl:(NSString *) url
      retryAttempt:(NSInteger) retryAttempt;

- (void)cancelCurrentImageLoad;
@end
