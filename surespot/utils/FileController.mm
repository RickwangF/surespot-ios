//
//  FileController.m
//  surespot
//
//  Created by Adam on 7/22/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "FileController.h"
#import "NSData+Gunzip.h"
#include <zlib.h>
#include "secblock.h"
#import "IdentityController.h"
#import "DDLog.h"
#import "ChatUtils.h"

using CryptoPP::SecByteBlock;


NSString * const STATE_DIR = @"state";
NSString * const HOME_FILENAME = @"home";
NSString * const STATE_EXTENSION = @"sss";
NSString * const CHAT_DATA_PREFIX = @"chatdata_";

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@implementation FileController


+ (NSString*) getAppSupportDir {
    NSString *appSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    //If there isn't an App Support Directory yet ...
    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDir isDirectory:NULL]) {
        NSError *error = nil;
        //Create one
        if (![[NSFileManager defaultManager] createDirectoryAtPath:appSupportDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogVerbose(@"%@", error.localizedDescription);
        }
        else {
            // *** OPTIONAL *** Mark the directory as excluded from iCloud backups
            NSURL *url = [NSURL fileURLWithPath:appSupportDir];
            if (![url setResourceValue:[NSNumber numberWithBool:YES]
                                forKey:NSURLIsExcludedFromBackupKey
                                 error:&error])
            {
                DDLogVerbose(@"Error excluding %@ from backup %@", [url lastPathComponent], error.localizedDescription);
            }
            else {
                DDLogVerbose(@"Yay");
            }
        }
    }
    
    return appSupportDir;
}

+(NSString *) getHomeFilename {
    return [self getFilename:HOME_FILENAME];
}

+(NSString *) getChatDataFilenameForSpot: (NSString *) spot {
    return [self getFilename:[CHAT_DATA_PREFIX stringByAppendingString:spot]];
}

+(void) wipeDataForUsername: (NSString *) username friendUsername: (NSString *) friendUsername {
    //todo delete public keys
    
    
    
    NSString * spot = [ChatUtils getSpotUserA:username userB:friendUsername];
    NSString * messageFile = [self getChatDataFilenameForSpot:spot];
    
    DDLogInfo( @"wiping data for username: %@, friendname: %@, path: %@", username,friendUsername,messageFile);
    //file manager thread safe supposedly
    NSFileManager * fileMgr = [NSFileManager defaultManager];
    BOOL wiped = [fileMgr removeItemAtPath:messageFile error:nil];
    
    DDLogInfo(@"wiped: %@", wiped ? @"YES" : @"NO");
    
}



+(NSString *) getFilename: (NSString *) filename {
    return [self getFilename:filename forUser:[[IdentityController sharedInstance] getLoggedInUser]];
}

+(NSString *) getFilename: (NSString *) filename forUser: (NSString *) user {
    if (user) {
        NSString * dir = [[[FileController getAppSupportDir] stringByAppendingPathComponent:STATE_DIR ] stringByAppendingPathComponent:user];
        NSError * error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogVerbose(@"%@", error.localizedDescription);
        }
        
        return [dir stringByAppendingPathComponent:[filename stringByAppendingPathExtension:STATE_EXTENSION]];
                
    }
    
    return nil;
}


// http://cocoadev.com/wiki/NSDataCategory
+ (NSData *)gzipInflate:(NSData *) data
{
	if ([data length] == 0) return data;
	
	unsigned full_length = [data length];
	unsigned half_length = [data length] / 2;
	
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	strm.next_in = (Bytef *)[data bytes];
	strm.avail_in = [data length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
	while (!done)
	{
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
		strm.next_out = (byte *)[decompressed mutableBytes] + strm.total_out;
		strm.avail_out = [decompressed length] - strm.total_out;
		
		// Inflate another chunk.
		status = inflate (&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if (inflateEnd (&strm) != Z_OK) return nil;
	
	// Set real length.
	if (done)
	{
		[decompressed setLength: strm.total_out];
		return [NSData dataWithData: decompressed];
	}
	else return nil;
}

+ (NSData *)gzipDeflate:(NSData *) data
{
	if ([data length] == 0) return data;
	
	z_stream strm;
	
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.total_out = 0;
	strm.next_in=(Bytef *)[data bytes];
	strm.avail_in = [data length];
	
	// Compresssion Levels:
	//   Z_NO_COMPRESSION
	//   Z_BEST_SPEED
	//   Z_BEST_COMPRESSION
	//   Z_DEFAULT_COMPRESSION
	
	if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) return nil;
	
	NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chunks for expansion
	
	do {
		
		if (strm.total_out >= [compressed length])
			[compressed increaseLengthBy: 16384];
		
		strm.next_out = (byte *)[compressed mutableBytes] + strm.total_out;
		strm.avail_out = [compressed length] - strm.total_out;
		
		deflate(&strm, Z_FINISH);
		
	} while (strm.avail_out == 0);
	
	deflateEnd(&strm);
	
	[compressed setLength: strm.total_out];
	return [NSData dataWithData:compressed];
}

@end
