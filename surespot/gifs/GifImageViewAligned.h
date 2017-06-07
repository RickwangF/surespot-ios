//
//  UIImageViewAligned.h
//  awards
//
//  Created by Andrei Stanescu on 7/29/13.
//  Modded by adam o 6/6/17
//

#import <UIKit/UIKit.h>
#import "FLAnimatedImage.h"
#import "UIImageViewAligned.h"

@interface GifImageViewAligned : UIImageView

// This property holds the current alignment
@property (nonatomic) UIImageViewAlignmentMask alignment;

// Properties needed for Interface Builder quick setup
@property (nonatomic) BOOL alignLeft;
@property (nonatomic) BOOL alignRight;
@property (nonatomic) BOOL alignTop;
@property (nonatomic) BOOL alignBottom;

// Make the UIImageView scale only up or down
// This are used only if the content mode is Scaled
@property (nonatomic) BOOL enableScaleUp;
@property (nonatomic) BOOL enableScaleDown;

// Just in case you need access to the inner image view
@property (nonatomic, readonly) FLAnimatedImageView* realImageView;

@end
