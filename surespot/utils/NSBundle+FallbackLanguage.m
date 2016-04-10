#import "NSBundle+FallbackLanguage.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@implementation NSBundle (FallbackLanguage)

- (NSString *)localizedStringForKey:(NSString *)key replaceValue:(NSString *)comment {
    
    NSString *localizedString = [[NSBundle mainBundle] localizedStringForKey:key value:@"" table:nil];

    NSArray *preferredLanguagesIncDefault = [NSLocale preferredLanguages];
    NSString * preferredLanguage = [preferredLanguagesIncDefault objectAtIndex:0];
    NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:preferredLanguage];
    NSString *languageCode = [languageDic objectForKey:@"kCFLocaleLanguageCodeKey"];
    
    DDLogVerbose(@"localizedStringForKey: %@, preferred language: %@", key, languageCode);
    
    //if we found it or default language is english return it
    if ([languageCode isEqualToString:@"en"] || ![localizedString isEqualToString:key]) {
        DDLogVerbose(@"localizedStringForKey: %@ found", key);
        return localizedString;
    }
    
    //didn't find it in default
    //iterate through preferred languages till we find a string
    //return english if we don't
    //already tested first language as it's the default so lop that off
    NSMutableArray *preferredLanguages = [NSMutableArray arrayWithArray:preferredLanguagesIncDefault];
    [preferredLanguages removeObjectAtIndex:0];
    
    //TODO revisit if we want to utilize country specific languages
    NSArray *supportedLanguages = [NSArray arrayWithObjects:@"en",@"de",@"it",@"es",@"fr", nil];
    
    for (NSString * language in preferredLanguages) {
        
        //add languages only

        NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:language];
        NSString *languageCode = [languageDic objectForKey:@"kCFLocaleLanguageCodeKey"];
        //    NSString *countryCode = [languageDic objectForKey:@"kCFLocaleCountryCodeKey"];
        
        //if we don't support the language don't bother looking
        if (![supportedLanguages containsObject:languageCode]) {
            DDLogVerbose(@"localizedStringForKey: %@ no fallback translation for languageCode: %@",key, languageCode);
            continue;
        }
        
        NSString *fallbackBundlePath = [[NSBundle mainBundle] pathForResource:languageCode ofType:@"lproj"];
        NSBundle *fallbackBundle = [NSBundle bundleWithPath:fallbackBundlePath];
        NSString *fallbackString = [fallbackBundle localizedStringForKey:key value:@"" table:nil];
        if (fallbackString) {
            localizedString = fallbackString;
        }
        if (![localizedString isEqualToString:key]) {
            DDLogVerbose(@"localizedStringForKey: %@ found fallback translation for languageCode: %@",key, languageCode);
            break;
        }
        
    }
    //if we didn't find it return english
    if ([localizedString isEqualToString:key]) {
        DDLogVerbose(@"localizedStringForKey: %@ falling back to english", key);
        NSString *fallbackBundlePath = [[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"];
        NSBundle *fallbackBundle = [NSBundle bundleWithPath:fallbackBundlePath];
        NSString *fallbackString = [fallbackBundle localizedStringForKey:key value:comment table:nil];
        localizedString = fallbackString;
    }
    
    return localizedString;

  }


+ (NSString *)localizedStringForKey:(NSString *)key replaceValue:(NSString *)comment bundle: (NSBundle *) bundle table: (id) table {
    
    NSString *localizedString = [bundle localizedStringForKey:key value:@"" table:table];
    
    NSArray *preferredLanguagesIncDefault = [NSLocale preferredLanguages];
    NSString * preferredLanguage = [preferredLanguagesIncDefault objectAtIndex:0];
    NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:preferredLanguage];
    NSString *languageCode = [languageDic objectForKey:@"kCFLocaleLanguageCodeKey"];
    
    DDLogVerbose(@"localizedStringForKey: %@, preferred languageCode: %@", key, languageCode);
    
    //if we found it or default language is english return it
    if ([languageCode isEqualToString:@"en"] || ![localizedString isEqualToString:key]) {
        DDLogVerbose(@"localizedStringForKey: %@ found", key);
        return localizedString;
    }
    
    //didn't find it in default
    //iterate through preferred languages till we find a string
    //return english if we don't
    //already tested first language as it's the default so lop that off
    NSMutableArray *preferredLanguages = [NSMutableArray arrayWithArray:preferredLanguagesIncDefault];
    [preferredLanguages removeObjectAtIndex:0];
    
    //TODO revisit if we want to utilize country specific languages
    NSArray *supportedLanguages = [NSArray arrayWithObjects:@"en",@"de",@"it",@"es","fr", nil];
    
    for (NSString * language in preferredLanguages) {
        
        //add languages only
        
        NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:language];
        NSString *languageCode = [languageDic objectForKey:@"kCFLocaleLanguageCodeKey"];
        //    NSString *countryCode = [languageDic objectForKey:@"kCFLocaleCountryCodeKey"];
        
        //if we don't support the language don't bother looking
        if (![supportedLanguages containsObject:languageCode]) {
            DDLogVerbose(@"localizedStringForKey: %@ no fallback translation for languageCode: %@",key, languageCode);
            continue;
        }
        
        NSString *fallbackBundlePath = [bundle pathForResource:languageCode ofType:@"lproj"];
        NSBundle *fallbackBundle = [NSBundle bundleWithPath:fallbackBundlePath];
        NSString *fallbackString = [fallbackBundle localizedStringForKey:key value:@"" table:table];
        if (fallbackString) {
            localizedString = fallbackString;
        }
        if (![localizedString isEqualToString:key]) {
            DDLogVerbose(@"localizedStringForKey: %@ found fallback translation for languageCode: %@",key, languageCode);
            break;
        }
        
    }
    //if we didn't find it return english
    if ([localizedString isEqualToString:key]) {
        DDLogVerbose(@"localizedStringForKey: %@ falling back to english", key);
        NSString *fallbackBundlePath = [bundle pathForResource:@"en" ofType:@"lproj"];
        NSBundle *fallbackBundle = [NSBundle bundleWithPath:fallbackBundlePath];
        NSString *fallbackString = [fallbackBundle localizedStringForKey:key value:comment table:table];
        localizedString = fallbackString;
    }
    
    return localizedString;
    
}


    

@end
