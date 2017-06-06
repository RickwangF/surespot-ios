//
//  GiphyView.h
//  surespot
//
//  Created by Adam on 5/11/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SurespotConstants.h"


@interface GiphyView : UIView <UICollectionViewDelegate, UICollectionViewDataSource>
-(void) setCallback: (CallbackBlock) callback;
-(void) searchGifs: (NSString *) query;
-(void) loadRecentGifs: (NSString *) username;
@end
