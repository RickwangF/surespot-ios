//
//  LineNumberLogFormatter.m
//  surespot
//
//  Created by Adam on 11/8/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "SurespotLogFormatter.h"


@implementation SurespotLogFormatter

- (id)init
{
    if((self = [super init]))
    {
        threadUnsafeDateFormatter = [[NSDateFormatter alloc] init];
        [threadUnsafeDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [threadUnsafeDateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss:SSS"];
    }
    return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    NSString *logLevel;
    switch (logMessage.flag)
    {
        case DDLogFlagError   : logLevel = @"E"; break;
        case DDLogFlagWarning : logLevel = @"W"; break;
        case DDLogFlagInfo    : logLevel = @"I"; break;
        default               : logLevel = @"V"; break;
    }
    
    NSString * function = [logMessage.function stringByPaddingToLength:12 withString:@" " startingAtIndex:0];
    
    NSString *dateAndTime = [threadUnsafeDateFormatter stringFromDate:(logMessage.timestamp)];
    NSString *fileName = [[[logMessage.file lastPathComponent] stringByDeletingPathExtension] stringByPaddingToLength:12 withString:@" " startingAtIndex:0];
    
//    NSString *qLabel = [NSString stringWithUTF8String:logMessage->queueLabel] substringFromIndex:
    return [NSString stringWithFormat:@"%@ %@ [%5@:%@] [%8@:%@ %3lu] %@",logLevel, dateAndTime, logMessage.threadID, logMessage.queueLabel, fileName, function, (unsigned long) logMessage.line, logMessage.message];
}
@end
