//
//  SurespotButton.m
//  surespot
//
//  Created by Adam on 11/9/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "SurespotButton.h"
#import "UIUtils.h"

@implementation SurespotButton


-(void) setHighlighted:(BOOL)highlighted {
    
  
    if(highlighted || [self isSelected]) {
        self.tintColor = [UIUtils surespotBlue];
    } else {
    
        self.tintColor = [UIUtils isBlackTheme] ? [UIUtils surespotForegroundGrey] : [UIUtils surespotGrey];
    }
    [super setHighlighted:highlighted];

 }

-(void) setSelected:(BOOL)selected {

    if(selected || [self isHighlighted]) {
        self.tintColor = [UIUtils surespotBlue];
    } else {
        self.tintColor = [UIUtils isBlackTheme] ? [UIUtils surespotForegroundGrey] : [UIUtils surespotGrey];
    }
    
    [super setSelected:selected];
}

//button smaller so make hit area bigger
//https://stackoverflow.com/questions/31056703/how-can-i-increase-the-tap-area-for-uibutton
-(BOOL) pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    NSInteger padding = 10;
    CGRect newArea = CGRectMake(self.bounds.origin.x - padding, self.bounds.origin.y - padding, self.bounds.size.width + padding*2, self.bounds.size.height + padding*2);
    return CGRectContainsPoint(newArea, point);
}
@end
