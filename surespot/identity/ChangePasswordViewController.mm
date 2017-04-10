//
//  ChangePasswordViewController.m
//  surespot
//
//  Created by Adam on 12/20/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "ChangePasswordViewController.h"
#import "IdentityController.h"
#import "CocoaLumberjack.h"
#import "SurespotConstants.h"
#import "UIUtils.h"
#import "LoadingView.h"
#import "FileController.h"
#import "NSData+Gunzip.h"
#import "NSString+Sensitivize.h"
#import "NSData+Base64.h"
#import "NSData+SRB64Additions.h"
#import "EncryptionController.h"
#import "NetworkManager.h"
#import "SurespotAppDelegate.h"
#import "BackupIdentityViewController.h"
#import "NSBundle+FallbackLanguage.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif


@interface ChangePasswordViewController ()
@property (strong, nonatomic) IBOutlet UILabel *label1;
@property (strong, nonatomic) IBOutlet UILabel *label2;
@property (atomic, strong) NSArray * identityNames;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;
@property (strong, nonatomic) IBOutlet UIButton *bExecute;
@property (atomic, strong) id progressView;
@property (strong, nonatomic) IBOutlet UITextField *currentPassword;
@property (strong, nonatomic) IBOutlet UITextField *shinyNewPassword;
@property (strong, nonatomic) IBOutlet UITextField *confirmPassword;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (nonatomic, assign) CGFloat delta;
@property (atomic, strong) NSString * name;
@end



@implementation ChangePasswordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"password", nil)];
    [_bExecute setTitle:NSLocalizedString(@"change_password", nil) forState:UIControlStateNormal];
    [self loadIdentityNames];
    self.navigationController.navigationBar.translucent = NO;
    
    _label1.text = NSLocalizedString(@"warning_password_reset", nil);
    _label1.textColor = [UIColor redColor];
    _label2.text = NSLocalizedString(@"backup_identities_again_password",nil);
    _label2.textColor = [UIColor redColor];
    
    [_currentPassword setPlaceholder: NSLocalizedString(@"current_password",nil)];
    [_shinyNewPassword setPlaceholder: NSLocalizedString(@"new_password",nil)];
    [_confirmPassword setPlaceholder: NSLocalizedString(@"confirm_password",nil)];
    
    [_scrollView setContentSize: CGSizeMake(self.view.frame.size.width, _bExecute.frame.origin.y + _bExecute.frame.size.height)];
    _delta = 0;

    [_userPicker selectRow:[_identityNames indexOfObject:[[IdentityController sharedInstance] getLoggedInUser]] inComponent:0 animated:YES];
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    if (theTextField == self.currentPassword) {
        [_shinyNewPassword becomeFirstResponder];
    }
    else {
        
        if (theTextField == self.shinyNewPassword) {
            [_confirmPassword becomeFirstResponder];
        }
        else {
            if (theTextField == self.confirmPassword) {
                [theTextField resignFirstResponder];
                [self changePassword];
            }
        }
    }
    return YES;
}


-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self registerForKeyboardNotifications];
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self unregisterKeyboardNotifications];
}


- (void)registerForKeyboardNotifications
{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeShown:)
                                                     name:UIKeyboardWillShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden:)
                                                     name:UIKeyboardWillHideNotification object:nil];
}

-(void) unregisterKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWillBeShown:(NSNotification*)aNotification {
    DDLogInfo(@"keyboard shown");
    NSDictionary* info = [aNotification userInfo];
    NSTimeInterval animationDuration;
    UIViewAnimationOptions curve;
    [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&curve];
    CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardRect.size.height;
    CGFloat totalHeight = self.view.frame.size.height;
    CGFloat keyboardTop = totalHeight - keyboardHeight;
    
    // run animation using keyboard's curve and duration
    [UIView animateWithDuration:animationDuration delay:0.0 options:curve animations:^{
        CGRect buttonFrame = _bExecute.frame;
        CGFloat createButtonBottom = buttonFrame.origin.y + buttonFrame.size.height ;
        CGFloat delta = keyboardTop - createButtonBottom;
        CGFloat deltaDelta = _delta - delta;
        _delta = delta;
        
        DDLogInfo(@"delta %f loginBottom %f keyboardtop: %f", deltaDelta, createButtonBottom, keyboardTop);
        
        if (delta < 10 ) {
            UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardHeight, 0.0);
            _scrollView.contentInset = contentInsets;
            _scrollView.scrollIndicatorInsets = contentInsets;
            CGPoint scrollPoint = CGPointMake(0.0, _scrollView.contentOffset.y + deltaDelta);
            
            [_scrollView setContentOffset:scrollPoint animated:NO];
        }
        
        [self.view layoutIfNeeded];
        
    } completion:^(BOOL completion) {
        
    }];

}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSDictionary *) info
{
    DDLogInfo(@"keyboard hide");
    NSTimeInterval animationDuration;
    UIViewAnimationOptions curve;
    [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&curve];
    // run animation using keyboard's curve and duration
    [UIView animateWithDuration:animationDuration delay:0.0 options:curve animations:^{
        UIEdgeInsets contentInsets = UIEdgeInsetsZero;
        _scrollView.contentInset = contentInsets;
        _scrollView.scrollIndicatorInsets = contentInsets;
    } completion:^(BOOL completion) {
    }];
    
    _delta = 0.0f;
}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                duration:(NSTimeInterval)duration
{
    DDLogInfo(@"will rotate");
    [_currentPassword resignFirstResponder];
    [_shinyNewPassword resignFirstResponder];
    [_confirmPassword resignFirstResponder];
    _delta = 0.0f;
}

//- (void)textFieldDidBeginEditing:(UITextField *)textField
//{
//    _activeView = textField;
//}
//
//- (void)textFieldDidEndEditing:(UITextField *)textField
//{
//    _activeView = nil;
//}


-(void) loadIdentityNames {
    _identityNames = [[IdentityController sharedInstance] getIdentityNames];
}



// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [_identityNames count];
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



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (IBAction)execute:(id)sender {
    
    [self changePassword];
}

-(void) changePassword {
    NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    NSString * password = self.currentPassword.text;
    NSString * newPassword = self.shinyNewPassword.text;
    NSString * confirmPassword = self.confirmPassword.text;
    
    
    if ([UIUtils stringIsNilOrEmpty:username] || [UIUtils stringIsNilOrEmpty:password] || [UIUtils stringIsNilOrEmpty:newPassword] || [UIUtils stringIsNilOrEmpty:confirmPassword]) {
        return;
    }
    
    if ([newPassword isEqualToString:password]) {
        [UIUtils showToastKey:@"cannot_change_to_same_password" duration:2];
        _shinyNewPassword.text = @"";
        _confirmPassword.text = @"";        
        [_shinyNewPassword becomeFirstResponder];
        return;
    }
    
    if (![confirmPassword isEqualToString:newPassword]) {
        [UIUtils showToastKey:@"passwords_do_not_match" duration:1.5];
        _shinyNewPassword.text = @"";
        _confirmPassword.text = @"";
        [_shinyNewPassword becomeFirstResponder];
        return;
    }
    
    
    [_currentPassword resignFirstResponder];
    [_shinyNewPassword resignFirstResponder];
    [_confirmPassword resignFirstResponder];
    _progressView = [LoadingView showViewKey:@"change_password_progress"];
    
    SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
    if (!identity) {
        [_progressView removeView];
        _progressView = nil;

        [_currentPassword becomeFirstResponder];
        [UIUtils showToastKey: @"could_not_change_password" duration:2];
        return;
    }
    
    NSData * decodedSalt = [NSData dataFromBase64String: [identity salt]];
    NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: decodedSalt];
    NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
    
    NSData * signature = [EncryptionController signUsername:username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
    NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
    NSString * signatureString = [signature SR_stringByBase64Encoding];
    
    [[[NetworkManager sharedInstance] getNetworkController:username] getPasswordTokenForUsername:username
                                                        andPassword:passwordString
                                                       andSignature:signatureString
                                                       successBlock:^(NSURLSessionTask *operation, id responseObject) {
                                                           NSString * passwordToken = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                                                           NSDictionary * derived = [EncryptionController deriveKeyFromPassword:newPassword];
                                                           NSData * newSaltData = [derived objectForKey:@"salt"];
                                                           NSData * newPasswordData = [derived objectForKey:@"key"];
                                                           NSData * encodedNewPassword = [newPasswordData SR_dataByBase64Encoding];
                                                           NSString * newPasswordString = [newPasswordData SR_stringByBase64Encoding];
                                                           NSData * tokenSignature = [EncryptionController signData1:[NSData dataFromBase64String:passwordToken] data2:encodedNewPassword withPrivateKey:[identity getDsaPrivateKey]];
                                                           NSString * tokenSignatureString = [tokenSignature SR_stringByBase64Encoding];
                                                           
                                                           [[[NetworkManager sharedInstance] getNetworkController:username] changePasswordForUsername:username
                                                                                                             oldPassword:passwordString
                                                                                                             newPassword:newPasswordString
                                                                                                                 authSig:signatureString
                                                                                                                tokenSig:tokenSignatureString
                                                                                                              keyVersion:[identity latestVersion]
                                                                                                            successBlock:^(NSURLSessionTask *operation, id responseObject) {
                                                                                                                [[IdentityController sharedInstance] updatePasswordForUsername:username
                                                                                                                                                               currentPassword:password
                                                                                                                                                                   newPassword:newPassword
                                                                                                                                                                       newSalt:[newSaltData SR_stringByBase64Encoding]];
                                                                                                                
                                                                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                                    [_progressView removeView];
                                                                                                                    _progressView = nil;

                                                                                                                    [UIUtils showToastKey:@"password_changed" duration:2];
                                                                                                                    
                                                                                                                    BackupIdentityViewController * bvc = [[BackupIdentityViewController alloc] initWithNibName:@"BackupIdentityView" bundle:nil];
                                                                                                                    bvc.selectUsername = username;
                                                                                                                
                                                                                                                    UINavigationController * nav = self.navigationController;
                                                                                                                    [nav popViewControllerAnimated:NO];
                                                                                                                    [nav pushViewController:bvc animated:YES];
                                                                                                                });
  
                                                                                                            } failureBlock:^(NSURLSessionTask *operation, NSError *error) {
                                                                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                                    [_progressView removeView];
                                                                                                                    _progressView = nil;

                                                                                                                    [_currentPassword becomeFirstResponder];
                                                                                                                    [UIUtils showToastKey:@"could_not_change_password" duration:2];
                                                                                                                });
                                                                                                            }];
                                                           
                                                       } failureBlock:^(NSURLSessionTask *operation, NSError *error) {
                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                               [_currentPassword becomeFirstResponder];
                                                               [_progressView removeView];
                                                               _progressView = nil;

                                                               [UIUtils showToastKey:@"could_not_change_password" duration:2];
                                                           });
                                                       }];
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}




@end
