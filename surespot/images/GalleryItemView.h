//
//  GifSearchView.h
//  surespot
//
//  Created by Adam on 5/11/2017.
//  Copyright (c) 2017 surespot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FLAnimatedImage.h"

@interface GalleryItemView : UICollectionViewCell
@property (weak, nonatomic) NSString * url;
@property (weak, nonatomic) IBOutlet UIImageView *galleryView;
@end
