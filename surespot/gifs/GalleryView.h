//
//  GalleryView.h
//  surespot
//
//  Created by Adam on 5/17/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SurespotConstants.h"


@interface GalleryView : UIView <UICollectionViewDelegate, UICollectionViewDataSource>
-(void) setCallback: (CallbackBlock) callback;
-(void) fetchAssetsWithHeight: (NSInteger) height;
@end
