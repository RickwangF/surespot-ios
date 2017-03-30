//
//  SurespotViewController.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "LoginViewController.h"
#import "EncryptionController.h"
#import "IdentityController.h"
#import "NetworkController.h"
#import "NSData+Base64.h"
#import "NSData+SRB64Additions.h"
#import "UIUtils.h"
#import "LoadingView.h"
#import "CocoaLumberjack.h"
#import "RestoreIdentitiesViewController.h"
#import "RemoveIdentityFromDeviceViewController.h"
#import "SwipeViewController.h"
#import "HelpViewController.h"
#import "NSBundle+FallbackLanguage.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface LoginViewController ()
@property (atomic, strong) NSArray * identityNames;
@property (atomic, strong) id progressView;
@property (nonatomic, assign) CGFloat delta;
@property (strong, nonatomic) IBOutlet UITextField *textPassword;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;

- (IBAction)login:(id)sender;
@property (strong, nonatomic) IBOutlet UIButton *bLogin;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UISwitch *storePassword;
@property (strong, nonatomic) IBOutlet UILabel *storeKeychainLabel;
@property (strong, readwrite, nonatomic) REMenu *menu;
@end

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [_textPassword setPlaceholder:NSLocalizedString(@"password", nil)];
    [self.navigationItem setTitle:NSLocalizedString(@"login", nil)];
    [self loadIdentityNames];
    _delta = 0.0f;
    self.navigationController.navigationBar.translucent = NO;
    
    NSString * lastUser = [[NSUserDefaults standardUserDefaults] stringForKey:@"last_user"];
    NSInteger index = 0;
    
    if (lastUser) {
        index = [_identityNames indexOfObject:lastUser];
        if (index == NSNotFound) {
            index = 0;
        }
    }
    
    [_userPicker selectRow:index inComponent:0 animated:YES];
    
    [self updatePassword:[_identityNames objectAtIndex:index]];
    [self.storePassword setTintColor:[UIUtils surespotBlue]];
    [self.storePassword setOnTintColor:[UIUtils surespotBlue]];
    [self.bLogin setTintColor:[UIUtils surespotBlue]];
    [self.bLogin setTitle:NSLocalizedString(@"login", nil) forState:UIControlStateNormal];
    //  _textPassword.returnKeyType = UIReturnKeyGo;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resume:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"menu",nil) style:UIBarButtonItemStylePlain target:self action:@selector(showMenu)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    
    _storeKeychainLabel.text = NSLocalizedString(@"store_password_in_keychain", nil);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification) name:@"openedFromNotification" object:nil];
    
    [_scrollView setContentSize: CGSizeMake(self.view.frame.size.width, _bLogin.frame.origin.y + _bLogin.frame.size.height)];
}

- (void)registerForKeyboardNotifications
{
    //use old positioning pre ios 8
    
    if ([UIUtils isIOS8Plus]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeShown8:)
                                                     name:UIKeyboardWillShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden8:)
                                                     name:UIKeyboardWillHideNotification object:nil];
    }
    else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeShown7:)
                                                     name:UIKeyboardWillShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden7:)
                                                     name:UIKeyboardWillHideNotification object:nil];
        
    }
}

-(void) unregisterKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWillBeShown8:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    [self keyboardWillBeShown:info isIos8Plus: YES];
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWillBeShown7:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    [self keyboardWillBeShown:info isIos8Plus: NO];
    
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWillBeHidden8:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    [self keyboardWillBeHidden:info isIos8Plus: YES];
    
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWillBeHidden7:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    [self keyboardWillBeHidden:info isIos8Plus: NO];
    
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWillBeShown:(NSDictionary*)info isIos8Plus: (BOOL) isIos8Plus {
    DDLogInfo(@"keyboard shown");
    
    
    NSTimeInterval animationDuration;
    UIViewAnimationOptions curve;
    [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&curve];
    CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = isIos8Plus ? keyboardRect.size.height : [UIUtils keyboardHeightAdjustedForOrientation:keyboardRect.size];
    CGFloat totalHeight = self.view.frame.size.height;
    CGFloat keyboardTop = totalHeight - keyboardHeight;
    
    // run animation using keyboard's curve and duration
    [UIView animateWithDuration:animationDuration delay:0.0 options:curve animations:^{
        CGRect buttonFrame = _bLogin.frame;
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
- (void)keyboardWillBeHidden:(NSDictionary *) info isIos8Plus: (BOOL) isIos8Plus
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
    [_textPassword resignFirstResponder];
    _delta = 0.0f;
}


- (IBAction)login:(id)sender {
    NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    NSString * password = self.textPassword.text;
    
    if ([UIUtils stringIsNilOrEmpty:password]) {
        return;
    }
    
    DDLogVerbose(@"starting login");
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [_textPassword resignFirstResponder];
    _progressView = [LoadingView showViewKey:@"login_progress"];
    
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    dispatch_async(q, ^{
        DDLogVerbose(@"getting identity");
        SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
        DDLogVerbose(@"got identity");
        
        if (!identity) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_progressView removeView];
                _progressView = nil;
                
                [UIUtils showToastKey: @"login_check_password" ];
                [_textPassword becomeFirstResponder];
                _textPassword.text = @"";
                
                self.navigationItem.rightBarButtonItem.enabled = YES;
                
            });
            return;
        }
        
        
        
        
        DDLogVerbose(@"creating signature");
        
        NSData * decodedSalt = [NSData dataFromBase64String: [identity salt]];
        NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: decodedSalt];
        NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
        
        NSData * signature = [EncryptionController signUsername:identity.username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
        NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
        NSString * signatureString = [signature SR_stringByBase64Encoding];
        
        DDLogVerbose(@"logging in to server");
        [[NetworkController sharedInstance]
         loginWithUsername:identity.username
         andPassword:passwordString
         andSignature: signatureString
         successBlock:^(NSURLSessionTask *task, id JSON, NSHTTPCookie * cookie) {
             DDLogVerbose(@"login success");
             
             if (_storePassword.isOn) {
                 [[IdentityController sharedInstance] storePasswordForIdentity:username password:password];
             }
             
             
             [[IdentityController sharedInstance] userLoggedInWithIdentity:identity password: password cookie: cookie reglogin:NO];
             
             UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle: nil];
             SwipeViewController * svc = [storyboard instantiateViewControllerWithIdentifier:@"swipeViewController"];
             
             NSMutableArray *  controllers = [NSMutableArray new];
             [controllers addObject:svc];
             
             
             //show help view on iphone if tos hasn't been clicked
             BOOL tosClicked = [[NSUserDefaults standardUserDefaults] boolForKey:@"hasClickedTOS"];
             if (!tosClicked && [UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) {
                 HelpViewController *hvc = [[HelpViewController alloc] initWithNibName:@"HelpView" bundle:nil];
                 [controllers addObject:hvc];
             }
             
             [self.navigationController setViewControllers:controllers animated:YES];
             _textPassword.text = @"";
             
             [_progressView removeView];
             _progressView = nil;
             self.navigationItem.rightBarButtonItem.enabled = YES;
         }
         failureBlock:^(NSURLSessionTask *operation, NSError *Error) {
             DDLogVerbose(@"response failure: %@",  Error);
             [_progressView removeView];
             _progressView = nil;
             
             switch ([(NSHTTPURLResponse*) operation.response statusCode]) {
                 case 401:
                     [UIUtils showToastKey: @"login_check_password"];
                     _textPassword.text = @"";
                     break;
                 case 403:
                     [UIUtils showToastKey: @"login_update"];
                     break;
                 default:
                     [UIUtils showToastKey: @"login_try_again_later"];
             }
             
             [_textPassword becomeFirstResponder];
             self.navigationItem.rightBarButtonItem.enabled = YES;
             
         }];
    });
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self login: nil];
    [textField resignFirstResponder];
    return NO;
}

- (void)viewDidUnload {
    [self setUserPicker:nil];
    [super viewDidUnload];
}

-(void) loadIdentityNames {
    _identityNames = [[IdentityController sharedInstance] getIdentityNames];
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self refresh];
    [self registerForKeyboardNotifications];
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self unregisterKeyboardNotifications];
}

-(void) refresh {
    [self loadIdentityNames];
    [_userPicker reloadAllComponents];
    if ([_identityNames count] > 0) {
        [self updatePassword:[_identityNames objectAtIndex:[ _userPicker selectedRowInComponent:0]]];
    }
    else {
        _textPassword.text = nil;
        [_storePassword setOn:NO animated:NO];
    }
    [self handleNotification];
}


- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSUInteger newLength = [textField.text length] + [string length] - range.length;
    return (newLength >= 256) ? NO : YES;
}

-(void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSString * selectedUser = [_identityNames objectAtIndex:row];
    [self updatePassword:selectedUser];
    
}

-(void) updatePassword: (NSString *) username {
    DDLogInfo(@"user changed: %@", username);
    NSString * password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:username];
    if (password) {
        _textPassword.text = password;
        [_storePassword setOn:YES animated:NO];
    }
    else {
        _textPassword.text = nil;
        [_storePassword setOn:NO animated:NO];
    }
    
}


-(void) resume:(NSNotification *)notification {
    DDLogInfo(@"resume");
    [_textPassword resignFirstResponder];
}

-(void) showMenu {
    
    if (!_menu) {
        [_textPassword resignFirstResponder];
        _menu = [self createMenu];
        if (_menu) {
            [_menu showInView:self.view];
        }
    }
    else {
        [_menu close];
    }
    
}

-(REMenu *) createMenu {
    //menu menu
    
    NSMutableArray * menuItems = [NSMutableArray new];
    
    REMenuItem * createItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"create_identity_label", nil) image:[UIImage imageNamed:@"ic_menu_add"] highlightedImage:nil action:^(REMenuItem * item){
        if ([[IdentityController sharedInstance] getIdentityCount] < MAX_IDENTITIES) {
            [self performSegueWithIdentifier: @"createSegue" sender: self];
        }
        else {
            [UIUtils showToastMessage:[NSString stringWithFormat: NSLocalizedString(@"login_max_identities_reached",nil), MAX_IDENTITIES] duration:2];
        }
    }];
    
    [menuItems addObject:createItem];
    
    REMenuItem * restoreItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"import_identities", nil) image:[UIImage imageNamed:@"ic_menu_archive"] highlightedImage:nil action:^(REMenuItem * item){
        RestoreIdentitiesViewController * controller = [[RestoreIdentitiesViewController alloc] init];
        [self.navigationController pushViewController:controller animated:YES];
        
    }];
    
    [menuItems addObject:restoreItem];
    
    REMenuItem * removeIdentityItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"remove_identity_from_device", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
        NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
        RemoveIdentityFromDeviceViewController * controller = [[RemoveIdentityFromDeviceViewController alloc] init];
        controller.selectUsername = username;
        [self.navigationController pushViewController:controller animated:YES];
    }];
    
    [menuItems addObject:removeIdentityItem];
    
    REMenuItem * clearCacheItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"clear_local_cache", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
        [UIUtils clearLocalCache];
        [UIUtils showToastKey:@"local_cache_cleared" duration:2];
    }];
    
    [menuItems addObject:clearCacheItem];
    
    return [UIUtils createMenu: menuItems closeCompletionHandler:^{
        _menu = nil;
    }];
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}

-(void) handleNotification {
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    DDLogInfo(@"handleNotification, defaults: %@", defaults);
    //if we entered app via notification defaults will be set
    NSString * notificationType = [defaults objectForKey:@"notificationType"];
    
    if ([notificationType isEqualToString:@"message"] || [notificationType isEqualToString:@"invite"]) {
        NSString * to = [defaults objectForKey:@"notificationTo"];
        NSInteger index = 0;
        index = [_identityNames indexOfObject:to];
        if (index == NSNotFound) {
            index = 0;
        }
        
        [_userPicker selectRow:index inComponent:0 animated:YES];
        [self updatePassword:to];
    }
}

- (IBAction)storeKeychainValueChanged:(id)sender {
    if (![_storePassword isOn]) {
        NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
        [[IdentityController sharedInstance] clearStoredPasswordForIdentity:username];
    }    
}


@end
