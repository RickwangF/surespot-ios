//
//  KeyFingerprintCollectionCell.m
//  surespot
//
//  Created by Adam on 12/23/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "KeyFingerprintCollectionCell.h"
#import "UIUtils.h"

@implementation KeyFingerprintCollectionCell
- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    
    self.label = [[UILabel alloc] initWithFrame:CGRectMake(0,0,20,18)];
    self.label.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.label.textAlignment = NSTextAlignmentCenter;
    [self.label setFont:[UIFont systemFontOfSize:13]];
    [self.contentView addSubview:self.label];


    if ([UIUtils isBlackTheme]) {
        [self.label setTextColor:[UIUtils surespotForegroundGrey]];
    }
    
    self.userInteractionEnabled = NO;
    
    return self;
}
@end
