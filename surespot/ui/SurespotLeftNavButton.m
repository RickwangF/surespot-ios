//
//  SurespotLeftNavButton.m
//  surespot
//
//  Created by Adam on 4/17/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import "SurespotLeftNavButton.h"

@interface SurespotLeftNavButton()
@property (assign, nonatomic) CGFloat inset;
@end


@implementation SurespotLeftNavButton



- (instancetype)initWithFrame:(CGRect)frame inset: (CGFloat) inset {
    _inset = inset;
    return [super initWithFrame:frame];
}

//get rid of the space around the left nav bar buttons
//http://stackoverflow.com/a/18918544
- (UIEdgeInsets)alignmentRectInsets {
    
    return  UIEdgeInsetsMake(0, _inset, 0, 0);
}

@end
