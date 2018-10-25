//
//  UIAnyLevelWindow.m
//  surespot
//
//  Created by Adam on 10/5/18.
//  Copyright © 2018 surespot. All rights reserved.
//

#import "UIAnyLevelWindow.h"

@interface UIAnyLevelWindow ()
@property (nonatomic, assign) UIWindowLevel anyWindowLevel;
@end

@implementation UIAnyLevelWindow

-  (id)initWithFrame:(CGRect)frame window: (UIWindow *) window
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        self.anyWindowLevel = [window windowLevel]+1;
    }
    
    return self;
}


- (UIWindowLevel) windowLevel {
    return _anyWindowLevel;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *resultView = [super hitTest:point withEvent:event];
    
    if (resultView == self) {
        return nil;
    } else {
        return resultView;
    }
    
    return resultView;
}

@end
