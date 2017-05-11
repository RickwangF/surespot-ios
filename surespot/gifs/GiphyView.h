//
//  UIView+giphyView.h
//  surespot
//
//  Created by Adam on 5/10/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SurespotConstants.h"

@interface GiphyView : UIView
-(void) setCallback: (CallbackBlock) callback;
-(void) searchGifs: (NSString *) query;
@end
