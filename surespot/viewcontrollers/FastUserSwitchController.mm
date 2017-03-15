//
//  FastUserSwitchController.m
//  surespot
//
//  Created by Adam on 3/15/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FastUserSwitchController.h"
#import "IdentityController.h"

@interface FastUserSwitchController ()
@property (atomic, strong) NSArray * identityNames;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;
@end

@implementation FastUserSwitchController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self loadIdentityNames];
    
    NSString * currentUser = [[IdentityController sharedInstance] getLoggedInUser];
    NSInteger index = 0;
    
    if (currentUser) {
        index = [_identityNames indexOfObject:currentUser];
        if (index == NSNotFound) {
            index = 0;
        }
    }
    
    
    [_userPicker selectRow:index inComponent:0 animated:YES];
    
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 37)];
    label.text =  [_identityNames objectAtIndex:row];
    [label setFont:[UIFont systemFontOfSize:22]];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    return label;
}

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [_identityNames count];
}

-(void) loadIdentityNames {
    _identityNames = [[IdentityController sharedInstance] getIdentityNames];
}


@end
