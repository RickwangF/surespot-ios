//
//  NSBundle+FallbackLanguage.m
//  Created by Alex Berkunov
//
//  The MIT License (MIT)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "NSBundle+FallbackLanguage.h"

@implementation NSBundle (FallbackLanguage)

- (NSString *)localizedStringForKey:(NSString *)key replaceValue:(NSString *)comment {
    
    NSString *localizedString = [[NSBundle mainBundle] localizedStringForKey:key value:@"" table:nil];
    //if we found it return it
    if (![localizedString isEqualToString:key]) {
        return localizedString;
    }
    
    //didn't find it in default
    //iterate through preferred languages till we find a string
    //return english if we don't
    NSArray *preferredLanguagesIncDefault = [NSLocale preferredLanguages];
    
    //already tested first language as it's the default so lop that off
    NSMutableArray *preferredLanguages = [NSMutableArray arrayWithArray:preferredLanguagesIncDefault];
    [preferredLanguages removeObjectAtIndex:0];
    
    
    for (NSString * language in preferredLanguages) {
        
        //add languages only
        //TODO revisit if we want to utilize country specific languages
        NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:language];
        NSString *languageCode = [languageDic objectForKey:@"kCFLocaleLanguageCodeKey"];
        //    NSString *countryCode = [languageDic objectForKey:@"kCFLocaleCountryCodeKey"];
        
        
        NSString *fallbackBundlePath = [[NSBundle mainBundle] pathForResource:languageCode ofType:@"lproj"];
        NSBundle *fallbackBundle = [NSBundle bundleWithPath:fallbackBundlePath];
        NSString *fallbackString = [fallbackBundle localizedStringForKey:key value:@"" table:nil];
        if (fallbackString) {
            localizedString = fallbackString;
        }
        if (![localizedString isEqualToString:key]) {
            break;
        }
        
    }
    //if we didn't find it return english
    if ([localizedString isEqualToString:key]) {
        NSString *fallbackBundlePath = [[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"];
        NSBundle *fallbackBundle = [NSBundle bundleWithPath:fallbackBundlePath];
        NSString *fallbackString = [fallbackBundle localizedStringForKey:key value:comment table:nil];
        localizedString = fallbackString;
    }
    
    return localizedString;

  }


    

@end
