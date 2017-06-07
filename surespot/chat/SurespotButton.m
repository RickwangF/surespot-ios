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


@end
