//
//  DownloadGifOperation.h
//  surespot
//
//  Created by Adam on 5/11/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#ifndef DownloadGifOperation_h
#define DownloadGifOperation_h

#import "SurespotMessage.h"
#import "SurespotConstants.h"
#import "FLAnimatedImage.h"

@interface DownloadGifOperation : NSOperation
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@property (nonatomic, strong) CallbackBlock callback;
-(id) initWithUrlString: (NSString *) urlString
             callback: (CallbackBlock) callback;
@property (nonatomic) NSString * urlString;
-(void) finish: (NSData *) data;
@end


#endif /* SendMessageOperation_h */
