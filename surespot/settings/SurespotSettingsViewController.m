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
#import "IASKSettingsReader.h"

#ifdef DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
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
        }
        self.neverShowPrivacySettings = YES;
    }
    
    return self;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell * cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
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

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger) section {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextAlignment:NSTextAlignmentCenter];
    if ([UIUtils isBlackTheme]) {
        [view setTintColor:[UIUtils surespotGrey]];
        [header.textLabel setTextColor:[UIUtils surespotForegroundGrey]];
    }
}

@end
