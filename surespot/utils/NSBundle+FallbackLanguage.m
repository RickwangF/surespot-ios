#import "NSBundle+FallbackLanguage.h"
#import "CocoaLumberjack.h"
#import "UIUtils.h"

#ifdef DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@implementation NSBundle (FallbackLanguage)

- (NSString *)localizedStringForKey:(NSString *)key replaceValue:(NSString *)comment {
    return [UIUtils localizedStringForKey:key replaceValue:comment bundle:[NSBundle mainBundle] table:nil];
}





@end
