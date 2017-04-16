//
//  AfterBackupIdentityHelpViewController.m
//
//  Copyright (c) 2015 surespot. All rights reserved.
//

#import "AfterBackupIdentityHelpViewController.h"
#import "UIUtils.h"
#import "NSBundle+FallbackLanguage.h"

@interface AfterBackupIdentityHelpViewController ()
@property (strong, nonatomic) IBOutlet TTTAttributedLabel *helpLabel;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@end

@implementation AfterBackupIdentityHelpViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSArray * matches = @[NSLocalizedString(@"file_sharing_match", nil)];
    NSArray * links = @[NSLocalizedString(@"file_sharing_link", nil)];
    NSString * label2Text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"after_identity_backup_what", nil)];
    
    //theme
    if ([UIUtils isBlackTheme]) {
        [self.scrollView setBackgroundColor:[UIUtils surespotGrey]];
        [self.helpLabel setTextColor:[UIUtils surespotForegroundGrey]];
    }
    
    [UIUtils setLinkLabel:_helpLabel delegate:self labelText:label2Text linkMatchTexts:matches urlStrings:links];
    
    _helpLabel.preferredMaxLayoutWidth = _helpLabel.frame.size.width;
    [_helpLabel sizeToFit];
    
    CGFloat bottom =  _helpLabel.frame.origin.y + _helpLabel.frame.size.height;
    
    CGSize size = self.view.frame.size;
    size.height = bottom + 20;
    _scrollView.contentSize = size;
    
    [self.navigationItem setTitle:NSLocalizedString(@"help", nil)];
    self.navigationController.navigationBar.translucent = NO;
}


- (void)attributedLabel:(__unused TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}



@end
