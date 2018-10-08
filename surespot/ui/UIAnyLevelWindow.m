//
//  UIAnyLevelWindow.m
//  surespot
//
//  Created by Adam on 10/5/18.
//  Copyright © 2018 surespot. All rights reserved.
//

#import "UIAnyLevelWindow.h"

@implementation UIAnyLevelWindow

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (UIWindowLevel) windowLevel {
    return 20000000.000;
}

@end
