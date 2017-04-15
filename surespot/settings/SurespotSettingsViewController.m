//
//  SurespotSettingsViewController.m
//  surespot
//
//  Created by Adam on 4/14/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SurespotSettingsViewController.h"
#import "CocoaLumberjack.h"
#import "UIUtils.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface SurespotSettingsViewController ()
@end



@implementation SurespotSettingsViewController
-(SurespotSettingsViewController *) init {
    if (self) {
        if ([UIUtils isBlackTheme]) {
            [self.view setBackgroundColor:[UIColor blackColor]];
            [self.tableView setBackgroundColor:[UIColor blackColor]];
            [self.tableView setSeparatorColor: [UIUtils surespotSeparatorGrey]];
            [self.tableView setSeparatorInset:UIEdgeInsetsZero];
        }
    }
    
    return self;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell * cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
        UISwitch * uiSwitch = (UISwitch *) cell.accessoryView;
        [UIUtils setUISwitchColors:uiSwitch];
    }
    
    if ([UIUtils isBlackTheme]) {
        [cell setBackgroundColor:[UIColor blackColor]];
        [cell.textLabel setTextColor:[UIUtils surespotForegroundGrey]];
        UIView *bgColorView = [[UIView alloc] init];
        bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
        bgColorView.layer.masksToBounds = YES;
        cell.selectedBackgroundView = bgColorView;

    }
    return cell;
}

- (UIView *)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section {
    UIView * view = [super tableView:tableView viewForHeaderInSection:section];
    view.layoutMargins = UIEdgeInsetsMake(0, 10, 0, 0);
    return view;
}
@end
