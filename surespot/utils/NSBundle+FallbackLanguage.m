#import "NSBundle+FallbackLanguage.h"
#import "DDLog.h"
#import "UIUtils.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@implementation NSBundle (FallbackLanguage)

- (NSString *)localizedStringForKey:(NSString *)key replaceValue:(NSString *)comment {
    return [UIUtils localizedStringForKey:key replaceValue:comment bundle:[NSBundle mainBundle] table:nil];
}





@end
