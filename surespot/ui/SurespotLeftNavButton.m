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



-(instancetype)initWithDimen:(CGFloat) dimen inset: (CGFloat) inset {
    _inset = inset;
    
    
    self = [super initWithFrame:CGRectMake(0, 0, dimen, dimen)];
    
    if (self) {
        //ios 11 fucks up image
        if (@available(iOS 11, *)) {
            [self.widthAnchor constraintEqualToConstant: dimen].active = YES;
            [self.heightAnchor constraintEqualToConstant: dimen].active = YES;            
        }
        
    }
    return self;
    
    
}

//get rid of the space around the left nav bar buttons
//http://stackoverflow.com/a/18918544
- (UIEdgeInsets)alignmentRectInsets {
    //ios 11 jacks insets
    if (@available(iOS 11, *)) {
          return  UIEdgeInsetsMake(0, _inset, 0, -_inset);
    }
    else {
        return  UIEdgeInsetsMake(0, _inset, 0, 0);
    }
}

@end
