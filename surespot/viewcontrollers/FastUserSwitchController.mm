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
#import "ChatManager.h"
#import "CredentialCachingController.h"
#import "UIUtils.h"

@interface FastUserSwitchController ()
@property (atomic, strong) NSArray * identityNames;
@property (weak, nonatomic) IBOutlet UILabel *activeIdentityLabel;
@property (weak, nonatomic) IBOutlet UITableView *userTableView;
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
    [_userTableView setScrollEnabled:NO];
    
    [_userTableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
    
    [[self view] setBackgroundColor: [UIColor clearColor]];
    [_activeIdentityLabel setTextColor:[UIUtils surespotBlue]];
    [_userTableView setBackgroundColor:[UIColor clearColor]];
    [_userTableView setSeparatorColor:[UIColor clearColor]];
    
    [self.navigationController setNavigationBarHidden:YES];
    
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self refresh];
}

-(void) refresh {
    [self loadIdentityNames];
    [_userTableView reloadData];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_identityNames count];
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *simpleTableIdentifier = @"SimpleTableItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
        [cell setBackgroundColor:[UIColor clearColor]];
        cell.textLabel.textColor = [UIColor whiteColor];
        UIView * bgColorView = [[UIView alloc] init];
        bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
        [cell setSelectedBackgroundView:bgColorView];
    }
    
    cell.textLabel.text = [_identityNames objectAtIndex:indexPath.row];
    return cell;
}

-(void) loadIdentityNames {
    _identityNames = [[IdentityController sharedInstance] getIdentityNames];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if ( [[_identityNames objectAtIndex:indexPath.row]isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]]) {
        return;
    }
    else {
        [self dismissViewControllerAnimated:YES completion:^{
            NSDictionary *userInfo = @{@"username": [_identityNames objectAtIndex:indexPath.row]};
            [[NSNotificationCenter defaultCenter] postNotificationName:@"fastUserSwitch" object:nil userInfo: userInfo];
        }];
    }
}



@end
