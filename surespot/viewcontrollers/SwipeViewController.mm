//
//  SwipeViewController.m
//  surespot
//
//  Created by Adam on 9/25/13.
//  Copyright (c) 2013-2017 surespot. All rights reserved.
//

#import "SwipeViewController.h"
#import "NetworkManager.h"
#import "ChatManager.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import <UIKit/UIKit.h>
#import "MessageView.h"
#import "ChatUtils.h"
#import "HomeCell.h"
#import "SurespotControlMessage.h"
#import "FriendDelegate.h"
#import "UIUtils.h"
#import "LoginViewController.h"
#import "CocoaLumberjack.h"
#import "REMenu.h"
#import "SVPullToRefresh.h"
#import "SurespotConstants.h"
#import "IASKAppSettingsViewController.h"
#import "IASKSettingsReader.h"
#import "ImageDelegate.h"
#import "MessageView+WebImageCache.h"
#import "SurespotPhoto.h"
#import "HomeCell+WebImageCache.h"
#import "KeyFingerprintViewController.h"
#import "QRInviteViewController.h"
#import "VoiceDelegate.h"
#import "PurchaseDelegate.h"
#import "SurespotSettingsStore.h"
#import "HelpViewController.h"
#import "UIAlertView+Blocks.h"
#import "LoadingView.h"
#import "UsernameAliasMap.h"
#import "NSBundle+FallbackLanguage.h"
#import "FastUserSwitchController.h"
#import "SideMenu-Swift.h"
#import "SurespotSettingsViewController.h"
#import "SurespotLeftNavButton.h"
#import "SurespotConfiguration.h"
#import "FLAnimatedImage.h"
#import "GiphyView.h"
#import "DownloadGifOperation.h"
#import "MessageView+GifCache.h"
#import "AGWindowView.h"
#import "GalleryView.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif


typedef NS_ENUM(NSInteger, MessageMode) {
    MessageModeNone,
    MessageModeKeyboard,
    MessageModeGIF,
    MessageModeCamera,
    MessageModeGallery,
    MessageModeMore
};

@interface SwipeViewController ()
@property (nonatomic, strong) dispatch_queue_t dateFormatQueue;
@property (nonatomic, strong) NSDateFormatter * dateFormatter;
@property (nonatomic, strong) UIViewPager * viewPager;
@property (nonatomic, strong) NSMutableDictionary * tabLoading;
@property (nonatomic, strong) NSMutableDictionary * needsScroll;
@property (strong, readwrite, nonatomic) REMenu *menu;
@property (nonatomic, weak) UIView * backImageView;
@property (atomic, assign) NSInteger scrollingTo;
@property (nonatomic, strong) NSMutableDictionary * bottomIndexPaths;
@property (nonatomic, strong) IASKAppSettingsViewController * appSettingsViewController;
@property (nonatomic, strong) ImageDelegate * imageDelegate;
@property (nonatomic, strong) SurespotMessage * imageMessage;
@property (nonatomic, strong) UIPopoverController * popover;
@property (nonatomic, strong) VoiceDelegate * voiceDelegate;
@property (nonatomic, strong) NSDate * buttonDownDate;
@property (strong, nonatomic) IBOutlet HPGrowingTextView *messageTextView;
@property (strong, nonatomic) IBOutlet HPGrowingTextView *inviteTextView;
@property (nonatomic, strong) NSTimer * buttonTimer;
@property (strong, nonatomic) IBOutlet UIImageView *bgImageView;
@property (nonatomic, assign) BOOL hasBackgroundImage;
@property (nonatomic, strong) IBOutlet SwipeView *swipeView;
@property (nonatomic, strong) UITableView *friendView;
@property (strong, atomic) NSMutableDictionary *chats;
@property (strong, nonatomic) MessageBarState * messageBarState;
@property (strong, nonatomic) IBOutlet UIButton *theButton;
- (IBAction)buttonTouchUpInside:(id)sender;
@property (strong, nonatomic) IBOutlet UIView *textFieldContainer;
@property (atomic, strong) LoadingView * progressView;
@property (atomic, strong) NSMutableArray *sideMenuGestures;
@property (atomic, strong) NSString * username;
@property (nonatomic, strong) NSMutableDictionary * progress;
@property (nonatomic, strong) NSArray<UIBarButtonItem *>* homeBackButtons;
@property (nonatomic, strong) NSArray<UIBarButtonItem *>* chatBackButtons;
@property (nonatomic, strong) UIBarButtonItem * backButtonItem;
@property (nonatomic, assign) enum MessageMode currentMode;
@property (strong, nonatomic) IBOutlet UIButton *gifButton;
@property (strong, nonatomic) IBOutlet UIButton *galleryButton;
@property (strong, nonatomic) IBOutlet UIButton *cameraButton;
@property (strong, nonatomic) IBOutlet UIButton *qrButton;
@property (nonatomic, strong) GiphyView * gifView;
@property (nonatomic, strong) GalleryView * galleryView;
@property (strong, nonatomic) IBOutlet HPGrowingTextView *giphySearchTextView;
@property (strong, nonatomic) IBOutlet UIImageView *giphyImage;
@property (strong, nonatomic) IBOutlet UIButton *expandButton;
@property (nonatomic, assign) NSInteger gifOffsets;
@property (nonatomic, assign) BOOL collapsed;
@property (nonatomic, strong) MessageView *ourPrototypeCell;
@property (nonatomic, strong) MessageView *theirPrototypeCell;
@property (nonatomic, strong) UIAlertController * alertController;
@property (nonatomic, assign) BOOL suspendKeyboardListeners;
@property (nonatomic, assign) NSInteger galleryHeight;

@end
@implementation SwipeViewController

const Float32 voiceRecordDelay = 0.3;

- (void)viewDidLoad
{
    DDLogDebug(@"swipeviewdidload %@", self);
    [super viewDidLoad];
    
    _currentMode = MessageModeNone;
    
    _username = [[IdentityController sharedInstance] getLoggedInUser];
    
    _tabLoading = [NSMutableDictionary new];
    _needsScroll = [NSMutableDictionary new];
    
    _dateFormatQueue = dispatch_queue_create("date format queue", NULL);
    _dateFormatter = [[NSDateFormatter alloc]init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    _chats = [[NSMutableDictionary alloc] init];
    
    //configure swipe view
    _swipeView.alignment = SwipeViewAlignmentCenter;
    _swipeView.pagingEnabled = YES;
    _swipeView.wrapEnabled = NO;
    _swipeView.truncateFinalPage =NO ;
    _swipeView.delaysContentTouches = YES;
    _swipeView.bounces = NO;
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    // [self registerForKeyboardNotifications];
    self.messageBarState = [[MessageBarState alloc] init];
    
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"menu",nil) style:UIBarButtonItemStylePlain target:self action:@selector(showMenuMenu)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    self.navigationItem.title = _username;
    
    //don't swipe to back stack
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    
    //listen for  notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshMessages:) name:@"refreshMessages" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshHome:) name:@"refreshHome" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteFriend:) name:@"deleteFriend" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startProgress:) name:@"startProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopProgress:) name:@"stopProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unauthorized:) name:@"unauthorized" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newMessage:) name:@"newMessage" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(invite:) name:@"invite" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inviteAccepted:) name:@"inviteAccepted" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:kIASKAppSettingChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundImageChanged:) name:@"backgroundImageChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification) name:@"openedFromNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userSwitch) name:@"userSwitch" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSwipeViewData) name:@"reloadSwipeView" object:nil];
    
    
    _viewPager = [[UIViewPager alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 30)];
    _viewPager.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_viewPager];
    _viewPager.delegate = self;
    
    CGRect swipeViewFrame = _swipeView.frame;
    swipeViewFrame.origin.y += 30;
    swipeViewFrame.size.height -= 30;
    _swipeView.frame = swipeViewFrame;
    
    NSString * chatFromDefaults = [self checkDefaultsForChat];
    
    //open active tabs, don't load data now well get it after connect
    for (Friend * afriend in [[[[ChatManager sharedInstance] getChatController:_username] getHomeDataSource] friends]) {
        if ([afriend isChatActive]) {
            [self loadChat:[afriend name] show:[[afriend name] isEqualToString:chatFromDefaults] scroll: NO availableId: -1 availableControlId:-1];
        }
    }
    
    [[[ChatManager sharedInstance] getChatController: _username] resume];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pause:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resume:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    _scrollingTo = -1;
    
    //app settings
    _appSettingsViewController = [SurespotSettingsViewController new];
    _appSettingsViewController.settingsStore = [[SurespotSettingsStore alloc] initWithUsername:_username];
    _appSettingsViewController.delegate = self;
    
    _messageTextView.enablesReturnKeyAutomatically = NO;
    [_messageTextView setFont:[UIFont systemFontOfSize:14]];
    [_messageTextView setMaxNumberOfLines:3];
    _messageTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _messageTextView.delegate = self;
    [_messageTextView.layer setBorderColor:[[UIColor grayColor] CGColor]];
    [_messageTextView.layer setBorderWidth:0.5];
    [_messageTextView setBackgroundColor:[UIColor clearColor]];
    _messageTextView.layer.cornerRadius = 5;
    
    _giphySearchTextView.enablesReturnKeyAutomatically = NO;
    [_giphySearchTextView setFont:[UIFont systemFontOfSize:14]];
    _giphySearchTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _giphySearchTextView.delegate = self;
    [_giphySearchTextView.layer setBorderColor:[[UIColor grayColor] CGColor]];
    [_giphySearchTextView.layer setBorderWidth:0.5];
    [_giphySearchTextView setBackgroundColor:[UIColor clearColor]];
    _giphySearchTextView.layer.cornerRadius = 5;
    [_giphySearchTextView setMaxNumberOfLines:1];
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageTextViewTapped:)];
    gestureRecognizer.numberOfTapsRequired = 1;
    gestureRecognizer.delegate = self;
    [_messageTextView addGestureRecognizer:gestureRecognizer];
    _messageBarState.origTextMessageFrame = _messageTextView.frame;
    
    gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(giphyImageViewTapped:)];
    gestureRecognizer.numberOfTapsRequired = 1;
    gestureRecognizer.delegate = self;
    [_giphyImage addGestureRecognizer:gestureRecognizer];
    
    
    _inviteTextView.enablesReturnKeyAutomatically = NO;
    [_inviteTextView setFont:[UIFont systemFontOfSize:14]];
    [_inviteTextView setMaxNumberOfLines:1];
    _inviteTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _inviteTextView.delegate = self;
    [_inviteTextView.layer setBorderColor:[[UIColor grayColor] CGColor]];
    [_inviteTextView.layer setBorderWidth:0.5];
    [_inviteTextView setBackgroundColor:[UIColor clearColor]];
    _inviteTextView.layer.cornerRadius = 5;
    [_inviteTextView.internalTextView setAutocorrectionType:UITextAutocorrectionTypeNo];
    [_inviteTextView.internalTextView setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [_inviteTextView.internalTextView setSpellCheckingType:UITextSpellCheckingTypeNo];
    
    _galleryHeight = MIN([[UIScreen mainScreen]bounds].size.height, [[UIScreen mainScreen] bounds].size.width)*.66;
    [self updateTabChangeUI];
    [self setBackButtonIcon];
    [self setTextBoxHints];
    [self setupSideView];
    [self setThemeStuff];
    [self disableMessageModeShowKeyboard:NO setResponders:NO];
    
}

- (void) setupSideView {
    DDLogVerbose(@"setupSideview");
    FastUserSwitchController * fusc = [[FastUserSwitchController alloc] initWithNibName:@"FastUserSwitchView" bundle:nil];
    
    UISideMenuNavigationController *sideC = [[UISideMenuNavigationController alloc] initWithRootViewController:fusc];
    sideC.leftSide = YES;
    
    
    [[SideMenuManager defaultManager] setMenuLeftNavigationController:sideC];
    _sideMenuGestures = [[NSMutableArray alloc]init];
    [_sideMenuGestures addObjectsFromArray: [[SideMenuManager defaultManager] menuAddScreenEdgePanGesturesToPresentToView:self.view forMenu:UIRectEdgeLeft]];
    [_sideMenuGestures addObjectsFromArray: [[SideMenuManager defaultManager] menuAddScreenEdgePanGesturesToPresentToView:self.navigationController.view forMenu:UIRectEdgeLeft]];
    [_sideMenuGestures addObjectsFromArray: [[SideMenuManager defaultManager] menuAddScreenEdgePanGesturesToPresentToView:self.swipeView.scrollView forMenu:UIRectEdgeLeft]];
    [SideMenuManager defaultManager].MenuPushStyle = MenuPushStyleSubMenu;
    [SideMenuManager defaultManager].menuPresentMode = MenuPresentModeMenuSlideIn;
    [SideMenuManager defaultManager].menuAnimationFadeStrength = 0.9;
    [SideMenuManager defaultManager].menuAnimationTransformScaleFactor = 0.9;
    [SideMenuManager defaultManager].menuFadeStatusBar = NO;
    //set gesture recognizer priority
    
    for (UIGestureRecognizer *gesture in _swipeView.scrollView.gestureRecognizers) {
        DDLogVerbose(@"gesture: %@)", gesture);
        for (UIGestureRecognizer *sideMenuGesture in _sideMenuGestures) {
            [gesture requireGestureRecognizerToFail:sideMenuGesture];
        }
    }
}

- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height
{
    DDLogVerbose(@"growingTextView height: %f", height);
    float diff = (growingTextView.frame.size.height - height);
    
    CGRect containerRect = _textFieldContainer.frame;
    containerRect.size.height -= diff;
    containerRect.origin.y += diff;
    _textFieldContainer.frame = containerRect;
    
    CGRect inviteRect = _inviteTextView.frame;
    inviteRect.origin.y -= diff;
    _inviteTextView.frame = inviteRect;
    
    CGRect gifRect = _giphySearchTextView.frame;
    gifRect.origin.y -= diff;
    _giphySearchTextView.frame = gifRect;
    
    [self adjustTableViewHeight:-diff];
}

-(void) adjustTableViewHeight: (NSInteger) height {
    DDLogDebug(@"adjustTableViewHeight: %ld", (long)height);
    CGRect frame = _swipeView.frame;
    frame.size.height -= height;
    _swipeView.frame = frame;
    
    UITableView * tableView = [_chats objectForKey: [self getCurrentTabName]];
    if ([tableView respondsToSelector:@selector(contentOffset)]) {
        CGPoint newOffset = CGPointMake(0, tableView.contentOffset.y + height);
        [tableView setContentOffset:newOffset animated:NO];
    }
}

-(void)growingTextViewDidChange:(HPGrowingTextView *)growingTextView {
    if (_collapsed) {
        CGRect frame = _messageBarState.origTextMessageFrame;
        frame.size.height = growingTextView.frame.size.height;
        frame.origin.y = growingTextView.frame.origin.y;
        _messageBarState.origTextMessageFrame = frame;
    }
    [self updateTabChangeUI];
}

/*
 -(void)growingTextView:(HPGrowingTextView *)growingTextView didChangeHeight:(float)height {
 
 }
 */

- (BOOL) growingTextView:(HPGrowingTextView *)growingTextView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *) string
{
    if (growingTextView == _giphySearchTextView) {
        if ([growingTextView.text isEqualToString:@""] && [string isEqualToString:@"\n"]) {
            [self disableMessageModeShowKeyboard:YES setResponders:YES];
            return NO;
        }
        
        if ([string containsString:@"\n"]) {
            [self searchGifs];
            return NO;
        }
        
        return YES;
        
    }
    
    
    
    if ([string containsString:@"\n"]) {
        if (growingTextView != _messageTextView || [UIUtils getBoolPrefWithDefaultYesForUser:_username key:@"_user_pref_return_sends_message"]) {
            [self handleTextAction];
            return NO;
        } else {
            return YES;
        }
    }
    
    if (growingTextView == _inviteTextView) {
        NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
        NSString * newString = [string stringByTrimmingCharactersInSet:alphaSet];
        if (![newString isEqualToString:@""]) {
            return NO;
        }
        
        NSUInteger newLength = [growingTextView.text length] + [newString length] - range.length;
        return (newLength >= 20) ? NO : YES;
    }
    else {
        if (growingTextView == _messageTextView) {
            NSUInteger newLength = [_messageTextView.text length] + [string length] - range.length;
            return (newLength >= 1024) ? NO : YES;
        }
    }
    return YES;
}


-(void) searchGifs {
    if ([_giphySearchTextView.text length] > 0) {
        [self.gifView searchGifs:_giphySearchTextView.text];
        [_giphySearchTextView setText:@""];
    }
    
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //show help in popover on ipad if it hasn't been shown yet
    BOOL tosClicked = [[NSUserDefaults standardUserDefaults] boolForKey:@"hasClickedTOS"];
    if (!tosClicked && [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        
        HelpViewController * hvc = [[HelpViewController alloc]                                                                                                            initWithNibName:@"HelpView" bundle:nil];
        
        _popover = [[UIPopoverController alloc] initWithContentViewController: hvc] ;
        _popover.delegate = self;
        CGFloat x = self.view.bounds.size.width;
        CGFloat y =self.view.bounds.size.height;
        DDLogVerbose(@"setting popover x, y to: %f, %f", x/2,y/2);
        hvc.poController = _popover;
        [_popover setPopoverContentSize:CGSizeMake(320, 480) animated:YES];
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
    }
    
    [self handleNotification];
    [self registerForKeyboardNotifications];
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self unregisterKeyboardNotifications];
}

- (void)sideMenuWillAppearWithMenu:(UISideMenuNavigationController * _Nonnull)menu animated:(BOOL)animated {
    [self disableMessageModeShowKeyboard:NO setResponders:YES];
}


-(void) pause: (NSNotification *)  notification{
    DDLogVerbose(@"pause");
    [[ChatManager sharedInstance] pause: _username];
    
    [self disableMessageModeShowKeyboard:NO setResponders:YES];
}


-(void) resume: (NSNotification *) notification {
    DDLogVerbose(@"resume");
    [[ChatManager sharedInstance] resume: _username];
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

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                duration:(NSTimeInterval)duration
{
    DDLogInfo(@"will rotate");
    [self disableMessageModeShowKeyboard:NO setResponders:YES];
    _messageBarState.keyboardHeight = 0;
    
    
    _swipeView.suppressScrollEvent = YES;
    
    
    _bottomIndexPaths = [NSMutableDictionary new];
    
    NSArray * visibleCells = [_friendView indexPathsForVisibleRows];
    if ([visibleCells count ] > 0) {
        
        id indexPath =[visibleCells objectAtIndex:[visibleCells count]-1];
        DDLogVerbose(@"saving index path %@ for home", indexPath );
        [_bottomIndexPaths setObject: indexPath forKey: @"" ];
        
    }
    
    //save scroll indices
    
    @synchronized (_chats) {
        for (NSString * key in [_chats allKeys]) {
            id tableView = [_chats objectForKey:key];
            
            if ([tableView respondsToSelector:@selector(indexPathsForVisibleRows)]) {
                NSArray * visibleCells = [tableView indexPathsForVisibleRows];
                
                if ([visibleCells count ] > 0) {
                    id indexPath =[visibleCells objectAtIndex:[visibleCells count]-1];
                    DDLogVerbose(@"saving index path %@ for key %@", indexPath , key);
                    [_bottomIndexPaths setObject: indexPath forKey: key ];
                }
            }
            
        }
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromOrientation
{
    DDLogInfo(@"did rotate");
    
    _swipeView.suppressScrollEvent= NO;
    
    [self showHeader];
    [self restoreScrollPositions];
    [self scrollToBottomOfTextView];
}

-(void)scrollToBottomOfTextView
{
    if(_messageTextView.text.length > 0 ) {
        NSRange bottom = NSMakeRange(_messageTextView.text.length -1, 1);
        [_messageTextView scrollRangeToVisible:bottom];
    }
}

-(void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView *__autoreleasing *)view {
    CGFloat x =self.view.bounds.size.width;
    CGFloat y =self.view.bounds.size.height;
    DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
    
    CGRect newRect = CGRectMake(x/2,y/2, 1,1 );
    *rect = newRect;
}


-(void) restoreScrollPositions {
    if (_bottomIndexPaths) {
        for (id key in [_bottomIndexPaths allKeys]) {
            if ([key isEqualToString:@""]) {
                
                if (![self getCurrentTabName]) {
                    id indexPath =[_bottomIndexPaths objectForKey:key];
                    DDLogVerbose(@"Scrolling home view to index %@", indexPath);
                    [self scrollTableViewToCell:_friendView indexPath: indexPath];
                    [_bottomIndexPaths removeObjectForKey:key ];
                }
            }
            else {
                if ([[self getCurrentTabName] isEqualToString:key]) {
                    id indexPath =[_bottomIndexPaths objectForKey:key];
                    DDLogVerbose(@"Scrolling %@ view to index %@", key,indexPath);
                    
                    UITableView * tableView = [_chats objectForKey:key];
                    [self scrollTableViewToCell:tableView indexPath:indexPath];
                    [_bottomIndexPaths removeObjectForKey:key ];
                }
            }
        }
    }
    
}

-(void) showHeader {
    DDLogDebug(@"showHeader");
    //if we're on iphone in landscape, hide the nav bar and status bar
    if ([[ UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone &&
        UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
        
        //if we're in landscape on iphone hide the menu
        [_menu close];
    }
    else {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void) swipeViewDidScroll:(SwipeView *)scrollView {
    // DDLogVerbose(@"swipeViewDidScroll");
    [_viewPager scrollViewDidScroll: scrollView.scrollView];
    
}

-(NSUInteger)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return ![_voiceDelegate isRecording];
}

-(void) switchToPageIndex:(NSInteger)page {
    _scrollingTo = page;
    [_swipeView scrollToPage:page duration:0.5f];
}

-(NSInteger) currentPage {
    return [_swipeView currentPage];
}

-(NSInteger) pageCount {
    return [self numberOfItemsInSwipeView:nil];
}

-(NSString * ) titleForLabelForPage:(NSInteger)page {
    // DDLogVerbose(@"titleForLabelForPage %ld", (long)page);
    if (page == 0) {
        return @"home";
    }
    else {
        return [self aliasForPage:page];    }
    
    return nil;
}

-(NSString * ) nameForPage:(NSInteger)page {
    
    if (page == 0) {
        return nil;
    }
    else {
        @synchronized (_chats) {
            if ([_chats count] > 0) {
                return [[[self sortedAliasedChats] objectAtIndex:page-1] username];
            }
        }
    }
    
    return nil;
}

-(NSString * ) aliasForPage:(NSInteger)page {
    
    if (page == 0) {
        return nil;
    }
    else {
        @synchronized (_chats) {
            if ([_chats count] > 0) {
                return [[[self sortedAliasedChats] objectAtIndex:page-1] alias];
            }
        }
    }
    
    return nil;
}

- (NSInteger)numberOfItemsInSwipeView:(SwipeView *)swipeView
{
    @synchronized (_chats) {
        return 1 + [_chats count];
    }
}

- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    //    DDLogDebug(@"view for item at index %ld", (long)index);
    if (index == 0) {
        if (!_friendView) {
            DDLogVerbose(@"creating friend view");
            
            _friendView = [[UITableView alloc] initWithFrame:swipeView.frame style: UITableViewStylePlain];
            _friendView.backgroundColor = [UIColor clearColor];
            [_friendView setSeparatorColor:[UIUtils surespotSeparatorGrey]];
            [_friendView registerNib:[UINib nibWithNibName:@"HomeCell" bundle:nil] forCellReuseIdentifier:@"HomeCell"];
            _friendView.delegate = self;
            _friendView.dataSource = self;
            
            [_friendView setSeparatorInset:UIEdgeInsetsZero];
            
            
            [self addLongPressGestureRecognizer:_friendView];
        }
        
        DDLogVerbose(@"returning friend view %@", _friendView);
        //return view
        return _friendView;
        
        
    }
    else {
        id theView;
        id aKey;
        @synchronized (_chats) {
            NSArray *keys = [self sortedAliasedChats];
            if ([keys count] > index - 1) {
                aKey = [keys objectAtIndex:index -1];
                theView = [_chats objectForKey:[aKey username]];
            }
        }
        
        //  DDLogDebug(@"returning chat view %@ for username: %@", theView, [aKey username]);
        return theView;
    }
}

-(void) addLongPressGestureRecognizer: (UITableView  *) tableView {
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(tableLongPress:) ];
    lpgr.minimumPressDuration = .7; //seconds
    [tableView addGestureRecognizer:lpgr];
    
}



- (void)swipeViewCurrentItemIndexDidChange:(SwipeView *)swipeView
{
    NSInteger currPage = swipeView.currentPage;
    DDLogInfo(@"swipeview index changed to %ld scrolling to: %ld", (long)currPage, (long)_scrollingTo);
    
    UITableView * tableview;
    if (currPage == 0) {
        [[[ChatManager sharedInstance] getChatController: _username] setCurrentChat:nil];
        tableview = _friendView;
        
        //stop pulsing
        [UIUtils stopPulseAnimation:_backImageView];
        _scrollingTo = -1;
        
        [tableview reloadData];
        
        if (_bottomIndexPaths) {
            id path = [_bottomIndexPaths objectForKey:@""];
            if (path) {
                [self scrollTableViewToCell:_friendView indexPath:path];
                [_bottomIndexPaths removeObjectForKey:@""];
            }
        }
        
        //update button
        [self updateTabChangeUI];
        [self disableMessageModeShowKeyboard:_messageBarState.keyboardHeight > 0 setResponders:YES];
        //  [self updateKeyboardState:YES];
        
        
    }
    else {
        @synchronized (_chats) {
            if (_scrollingTo == currPage || _scrollingTo == -1) {
                tableview = [self sortedValues][swipeView.currentPage-1];
                
                UsernameAliasMap * map = [self sortedAliasedChats][currPage-1];
                [[[ChatManager sharedInstance] getChatController: _username] setCurrentChat: map.username];
                _scrollingTo = -1;
                
                if (![[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] hasAnyNewMessages]) {
                    //stop pulsing
                    [UIUtils stopPulseAnimation:_backImageView];
                }
                
                if (![_tabLoading objectForKey:map.username]) {
                    //         [tableview reloadData];
                    
                    //scroll if we need to
                    BOOL scrolledUsingIndexPath = NO;
                    
                    
                    //if we've got saved scroll positions
                    if (_bottomIndexPaths) {
                        id path = [_bottomIndexPaths objectForKey:map.username];
                        if (path) {
                            DDLogVerbose(@"scrolling using saved index path for %@",map.username);
                            [self scrollTableViewToCell:tableview indexPath:path];
                            [_bottomIndexPaths removeObjectForKey:map.username];
                            scrolledUsingIndexPath = YES;
                        }
                    }
                    
                    if (!scrolledUsingIndexPath) {
                        @synchronized (_needsScroll ) {
                            id needsit = [_needsScroll  objectForKey:map.username];
                            if (needsit) {
                                DDLogVerbose(@"swipeViewCurrentItemIndexDidChange scrolling %@ to bottom",map.username);
                                [self performSelector:@selector(scrollTableViewToBottom:) withObject:tableview afterDelay:0.5];
                                [_needsScroll removeObjectForKey:map.username];
                            }
                        }
                    }
                }
                
                //update button
                [self updateTabChangeUI];
                [self updateKeyboardState:NO];
            }
        }
    }
    
    [self setBackButtonIcon];
}

- (void)swipeView:(SwipeView *)swipeView didSelectItemAtIndex:(NSInteger)index
{
    DDLogVerbose(@"Selected item at index %li", (long)index);
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    DDLogVerbose(@"number of sections");
    // Return the number of sections.
    return 1;
}

- (NSInteger) indexForTableView: (UITableView *) tableView {
    if (tableView == _friendView) {
        return 0;
    }
    @synchronized (_chats) {
        NSArray * sortedChats = [self sortedAliasedChats];
        for (int i=0; i<[_chats count]; i++) {
            if ([_chats objectForKey:[[sortedChats objectAtIndex:i] username]] == tableView) {
                return i+1;
                
            }
            
        }}
    
    return NSNotFound;
    
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSUInteger index = [self indexForTableView:tableView];
    
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    
    //    DDLogDebug(@"number of rows in section, index: %lu", (unsigned long)index);
    // Return the number of rows in the section
    if (index == 0) {
        if (![[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource]) {
            DDLogVerbose(@"returning 1 rows");
            return 1;
        }
        
        NSInteger count =[[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource].friends count];
        return count == 0 ? 1 : count;
    }
    else {
        
        
        NSInteger chatIndex = index-1;
        UsernameAliasMap * aliasMap;
        @synchronized (_chats) {
            
            NSArray *keys = [self sortedAliasedChats];
            if(chatIndex >= 0 && chatIndex < keys.count ) {
                aliasMap = [keys objectAtIndex:chatIndex];
            }
        }
        
        if ([_tabLoading objectForKey:aliasMap.username]) {
            return 1;
        }
        
        NSInteger count = [[[ChatManager sharedInstance] getChatController: _username] getDataSourceForFriendname: aliasMap.username].messages.count;
        return count == 0 ? 1 : count;
        
    }
    
    return 1;
}

-(double) textCellHeightTableView: (UITableView *) tableView  message: (SurespotMessage *) message {
    MessageView * cell;
    
    if ([ChatUtils isOurMessage:message ourUsername: _username]) {
        if (!_ourPrototypeCell) {
            _ourPrototypeCell = [tableView dequeueReusableCellWithIdentifier:@"OurMessageView"];
        }
        cell = _ourPrototypeCell;
    }
    else {
        if (!_theirPrototypeCell) {
            _theirPrototypeCell = [tableView dequeueReusableCellWithIdentifier:@"TheirMessageView"];
        }
        cell = _theirPrototypeCell;
    }
    
    [cell.messageLabel setText:[message plainData]];
    CGSize size = [cell.contentView systemLayoutSizeFittingSize:tableView.frame.size withHorizontalFittingPriority:1000 verticalFittingPriority:1 ];
    return size.height+1;
}

//needs to be implemented for UITableView autolayout to return correct sizes.
- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger index = [self indexForTableView:tableView];
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    
    if (index == NSNotFound) {
        return 0;
    }
    
    if (index == 0) {
        
        NSInteger count = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource].friends count];
        //if count is 0 we returned 1 for 0 rows so make the single row take up the whole height
        if (count == 0) {
            return tableView.frame.size.height;
        }
        
        Friend * afriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource].friends objectAtIndex:indexPath.row];
        if ([afriend isInviter] ) {
            return 70;
        }
        else {
            return 44;
        }
    }
    else {
        @synchronized (_chats) {
            
            NSArray *keys = [self sortedAliasedChats];
            UsernameAliasMap * map = [keys objectAtIndex:index -1];
            
            NSString * username = map.username;
            NSArray * messages = [[[ChatManager sharedInstance] getChatController: _username] getDataSourceForFriendname: username].messages;
            
            
            //if count is 0 we returned 1 for 0 rows so
            if (messages.count == 0) {
                return tableView.frame.size.height;
            }
            
            if (messages.count > 0 && (indexPath.row < messages.count)) {
                SurespotMessage * message = [messages objectAtIndex:indexPath.row];
                UIInterfaceOrientation  orientation = [[UIApplication sharedApplication] statusBarOrientation];
                double height = 0;
                
                //used cached values if we have them
                if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
                    height = message.rowLandscapeHeight;
                }
                else {
                    height = message.rowPortraitHeight;
                }
                
                //if height not cached
                if (height == 0) {
                    //fixed height for voice message
                    if ([message.mimeType isEqualToString: MIME_TYPE_M4A]) {
                        [UIUtils setVoiceMessageHeights:message];
                    }
                    else {
                        //fixed height for gifs and images
                        if ([message.mimeType isEqualToString: MIME_TYPE_IMAGE] || [message.mimeType isEqualToString: MIME_TYPE_GIF_LINK]) {
                            [UIUtils setImageMessageHeights:message];
                        }
                        else {
                            //if we have the text, cache the row height
                            if (![UIUtils stringIsNilOrEmpty:message.plainData]) {
                                height = [self textCellHeightTableView:tableView message:message];
                                
                                if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
                                    message.rowLandscapeHeight = height;
                                }
                                else {
                                    message.rowPortraitHeight = height;
                                }
                            }
                        }
                    }
                    
                    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
                        height = message.rowLandscapeHeight;
                    }
                    else {
                        height = message.rowPortraitHeight;
                    }
                }
                
                if (height == 0) {
                    height = 56;
                }
                
                return height;
            }
            else {
                return 0;
            }
        }
    }
}

-(UIColor *) getThemeForegroundColor {
    return _hasBackgroundImage ? [UIUtils surespotGrey] : ([UIUtils isBlackTheme] ? [UIUtils surespotForegroundGrey] : [UIColor blackColor]);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index = [self indexForTableView:tableView];
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    
    
    //    DDLogDebug(@"cell for row, index: %ld, indexPath: %@", (long)index, indexPath);
    if (index == NSNotFound) {
        static NSString *CellIdentifier = @"Cell";
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.backgroundColor = [UIColor clearColor];
        return cell;
        
    }
    
    
    
    if (index == 0) {
        NSInteger count =[[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource].friends count];
        
        if (count == 0) {
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.textLabel.text = NSLocalizedString(@"no_friends", nil);
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.textColor = [self getThemeForegroundColor];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.userInteractionEnabled = NO;
            return cell;
        }
        
        
        
        static NSString *CellIdentifier = @"HomeCell";
        HomeCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        // Configure the cell...
        Friend * afriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource].friends objectAtIndex:indexPath.row];
        cell.friendLabel.text = afriend.nameOrAlias;
        cell.friendLabel.textColor = [self getThemeForegroundColor];
        cell.backgroundColor = [UIColor clearColor];
        cell.friendName = afriend.name;
        cell.friendDelegate = [[ChatManager sharedInstance] getChatController: _username];
        
        BOOL isInviter =[afriend isInviter];
        
        [cell.ignoreButton setHidden:!isInviter];
        [cell.acceptButton setHidden:!isInviter];
        [cell.blockButton setHidden:!isInviter];
        
        
        cell.activeStatus.hidden = ![afriend isChatActive];
        cell.activeStatus.foregroundColor = [UIUtils surespotBlue];
        
        if (afriend.isInvited || afriend.isInviter || afriend.isDeleted) {
            cell.friendStatus.hidden = NO;
            
            if (afriend.isDeleted) {
                cell.friendStatus.text = NSLocalizedString(@"friend_status_is_deleted", nil);
            }
            
            if (afriend.isInvited) {
                cell.friendStatus.text = NSLocalizedString(@"friend_status_is_invited", nil);
            }
            
            if (afriend.isInviter) {
                cell.friendStatus.text = NSLocalizedString(@"friend_status_is_inviting", nil);
                [cell.blockButton setTitle:NSLocalizedString(@"block_underline", nil) forState:UIControlStateNormal];
                [cell.ignoreButton setTitle:NSLocalizedString(@"ignore_underline", nil) forState:UIControlStateNormal];
                [cell.acceptButton setTitle:NSLocalizedString(@"accept_underline", nil) forState:UIControlStateNormal];
            }
            cell.friendStatus.textAlignment = NSTextAlignmentCenter;
            cell.friendStatus.lineBreakMode = NSLineBreakByWordWrapping;
            cell.friendStatus.numberOfLines = 0;
            
            
        }
        else {
            cell.friendStatus.hidden = YES;
        }
        
        cell.messageNewView.hidden = !afriend.hasNewMessages;
        
        UIView *bgColorView = [[UIView alloc] init];
        bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
        bgColorView.layer.masksToBounds = YES;
        cell.selectedBackgroundView = bgColorView;
        
        if ([afriend hasFriendImageAssigned]) {
            EncryptionParams * ep = [[EncryptionParams alloc] initWithOurUsername:_username
                                                                       ourVersion:afriend.imageVersion
                                                                    theirUsername:afriend.name
                                                                     theirVersion:afriend.imageVersion
                                                                               iv:afriend.imageIv
                                                                           hashed:afriend.imageHashed];
            
            DDLogVerbose(@"setting friend image for %@ to %@", afriend.name, afriend.imageUrl);
            [cell setImageForFriend:afriend withEncryptionParams: ep placeholderImage:  [UIImage imageNamed:@"surespot_logo"] progress:^(NSUInteger receivedSize, long long expectedSize) {
                
            } completed:^(id image, NSString * mimeType, NSError *error, SDImageCacheType cacheType) {
                
            } retryAttempt:0];
        }
        else {
            DDLogVerbose(@"no friend image for %@", afriend.name);
            cell.friendImage.image = [UIImage imageNamed:@"surespot_logo"];
            [cell.friendImage setAlpha:.5];
        }
        
        //muting
        //        if ([afriend muted]) {
        //            if ([afriend hasFriendImageAssigned]) {
        //                [cell.friendImage setAlpha:.5];
        //            }
        //            else {
        //                [cell.friendImage setAlpha:0.25];
        //            }
        //            cell.muteImage.hidden = NO;
        //        }
        //        else {
        //            if ([afriend hasFriendImageAssigned]) {
        //                [cell.friendImage setAlpha:1.0];
        //            }
        //            else {
        //                [cell.friendImage setAlpha:.5];
        //            }
        //
        //            cell.muteImage.hidden = YES;
        //        }
        
        return cell;
    }
    else {
        UsernameAliasMap * aliasMap;
        @synchronized (_chats) {
            NSArray *keys = [self sortedAliasedChats];
            
            if ([keys count] > index - 1) {
                aliasMap = [keys objectAtIndex:index -1];
            }
            else {
                static NSString *CellIdentifier = @"Cell";
                UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
                cell.backgroundColor = [UIColor clearColor];
                cell.userInteractionEnabled = NO;
                return cell;
            }
        }
        
        NSString * username =  aliasMap.username;
        NSArray * messages = [[[ChatManager sharedInstance] getChatController: _username] getDataSourceForFriendname: username].messages;
        
        
        if (messages.count == 0) {
            DDLogVerbose(@"no chat messages");
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.textLabel.text = NSLocalizedString(@"no_messages", nil);
            cell.textLabel.textColor = [self getThemeForegroundColor];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.userInteractionEnabled = NO;
            return cell;
        }
        
        
        if (messages.count > 0 && indexPath.row < messages.count) {
            SurespotMessage * message =[messages objectAtIndex:indexPath.row];
            NSString * plainData = [message plainData];
            static NSString *OurCellIdentifier = @"OurMessageView";
            static NSString *TheirCellIdentifier = @"TheirMessageView";
            
            NSString * cellIdentifier;
            BOOL ours = NO;
            
            if ([ChatUtils isOurMessage:message ourUsername: _username]) {
                ours = YES;
                cellIdentifier = OurCellIdentifier;
                
            }
            else {
                cellIdentifier = TheirCellIdentifier;
            }
            MessageView *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
            if (!ours) {
                
                cell.messageSentView.foregroundColor = [UIUtils surespotBlue];
            }
            cell.backgroundColor = [UIColor clearColor];
            
            
            cell.messageLabel.textColor = [self getThemeForegroundColor];
            
            NSDictionary * linkAttributes = [NSMutableDictionary dictionary];
            [linkAttributes setValue:[NSNumber numberWithBool:YES] forKey:(NSString *)kCTUnderlineStyleAttributeName];
            [linkAttributes setValue:(__bridge id)[[UIUtils surespotBlue] CGColor] forKey:(NSString *)kCTForegroundColorAttributeName];
            
            cell.messageLabel.linkAttributes = linkAttributes;
            cell.messageLabel.delegate = self;
            
            
            cell.messageLabel.enabledTextCheckingTypes = NSTextCheckingTypeLink//phone number seems flaky..we have copy so not the end of teh world
            | NSTextCheckingTypePhoneNumber;
            
            cell.messageSize.textColor = [self getThemeForegroundColor];
            cell.messageStatusLabel.textColor = [self getThemeForegroundColor];
            
            cell.message = message;
            cell.messageLabel.text = plainData;
            
            UIView *bgColorView = [[UIView alloc] init];
            bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
            bgColorView.layer.masksToBounds = YES;
            cell.selectedBackgroundView = bgColorView;
            DDLogVerbose(@"message text x position: %f, width: %f", cell.messageLabel.frame.origin.x, cell.messageLabel.frame.size.width);
            
            if (message.errorStatus > 0) {
                NSString * errorText = [UIUtils getMessageErrorText: message.errorStatus mimeType:message.mimeType];
                DDLogVerbose(@"setting error status %@", errorText);
                [cell.messageStatusLabel setText: errorText];
                cell.messageSentView.foregroundColor = [UIColor blackColor];
            }
            else {
                
                if (message.serverid <= 0) {
                    DDLogVerbose(@"setting message sending");
                    cell.messageStatusLabel.text = NSLocalizedString(@"message_sending",nil);
                    
                    if (ours) {
                        cell.messageSentView.foregroundColor = [UIColor blackColor];
                    }
                }
                else {
                    if (!message.formattedDate) {
                        message.formattedDate = [self stringFromDate:[message dateTime]];
                    }
                    
                    if (ours) {
                        cell.messageSentView.foregroundColor = [UIColor lightGrayColor];
                    }
                    
                    if ((!message.plainData && ([message.mimeType isEqualToString:MIME_TYPE_TEXT] || [message.mimeType isEqualToString: MIME_TYPE_GIF_LINK])) ||
                        (([message.mimeType isEqualToString:MIME_TYPE_M4A] || [message.mimeType isEqualToString:MIME_TYPE_IMAGE]) && ![[SDWebImageManager sharedManager] isKeyCached: message.data])) {
                        DDLogVerbose(@"setting message loading");
                        cell.messageStatusLabel.text = NSLocalizedString(@"message_loading_and_decrypting",nil);
                    }
                    else {
                        
                        //   DDLogVerbose(@"setting text for iv: %@ to: %@", [message iv], plainData);
                        DDLogVerbose(@"setting message date");
                        cell.messageStatusLabel.text = message.formattedDate;
                        
                        if (ours) {
                            cell.messageSentView.foregroundColor = [UIColor lightGrayColor];
                        }
                        else {
                            cell.messageSentView.foregroundColor = [UIUtils surespotBlue];
                        }
                    }
                }
            }
            
            if ([message.mimeType isEqualToString:MIME_TYPE_TEXT] ||
                [message.mimeType isEqualToString:MIME_TYPE_FILE]) {
                cell.messageLabel.hidden = NO;
                cell.uiImageView.hidden = YES;
                cell.gifView.hidden = YES;
                cell.shareableView.hidden = YES;
                cell.audioIcon.hidden = YES;
                cell.audioSlider.hidden = YES;
                cell.messageSize.hidden = YES;
                CGRect messageStatusFrame = cell.messageStatusLabel.frame;
                if (ours) {
                    messageStatusFrame.origin.x = 13;
                }
                else {
                    messageStatusFrame.origin.x = 63;
                }
                cell.messageStatusLabel.frame = messageStatusFrame;
            }
            else {
                if ([message.mimeType isEqualToString:MIME_TYPE_IMAGE]) {
                    cell.shareableView.hidden = NO;
                    cell.messageLabel.hidden = YES;
                    cell.gifView.hidden = YES;
                    cell.uiImageView.image = nil;
                    cell.uiImageView.hidden = NO;
                    //  cell.uiImageView.alignTop = YES;
                    cell.uiImageView.alignLeft = YES;
                    cell.audioIcon.hidden = YES;
                    cell.audioSlider.hidden = YES;
                    if ([message dataSize ] > 0) {
                        cell.messageSize.hidden = NO;
                        cell.messageSize.text = [NSString stringWithFormat:@"%d KB", (int) ceil(message.dataSize/1000.0)];
                    }
                    else {
                        cell.messageSize.hidden = YES;
                    }
                    
                    
                    CGRect messageStatusFrame = cell.messageStatusLabel.frame;
                    if (ours) {
                        messageStatusFrame.origin.x = 22;
                    }
                    else {
                        messageStatusFrame.origin.x = 72;
                    }
                    
                    cell.messageStatusLabel.frame = messageStatusFrame;
                    
                    if (message.shareable) {
                        cell.shareableView.image = [UIImage imageNamed:@"ic_partial_secure"];
                    }
                    else {
                        cell.shareableView.image = [UIImage imageNamed:@"ic_secure"];
                    }
                    
                    [cell setMessage:message
                         ourUsername: _username
                            progress:^(NSUInteger receivedSize, long long expectedSize) {
                                
                            }
                           completed:^(id data, NSString * mimeType, NSError *error, SDImageCacheType cacheType) {
                               if (error) {
                                   
                               }
                           }
                        retryAttempt:0
                     
                     ];
                    
                    DDLogVerbose(@"imageView: %@", cell.uiImageView);
                }
                else {
                    if ([message.mimeType isEqualToString:MIME_TYPE_GIF_LINK]) {
                        cell.shareableView.hidden = NO;
                        cell.messageLabel.hidden = YES;
                        cell.uiImageView.hidden = YES;
                        
                        
                        cell.gifView.realImageView.image = nil;
                        cell.gifView.realImageView.animatedImage = nil;
                        
                        //download it if we sent it
                        message.downloadGif = ours || message.downloadGif;
                        
                        //otherwise check option
                        if (!message.downloadGif) {
                            bool downloadGifs = [UIUtils getBoolPrefWithDefaultNoForUser:_username key:@"_user_pref_download_gifs"];
                            if (!downloadGifs) {
                                UIImage * playGif = [UIImage imageNamed:([UIUtils isBlackTheme] ? @"play_circle_outline_light" : @"play_circle_outline_dark")];
                                
                                [cell.gifView.realImageView setContentMode:UIViewContentModeCenter];
                                cell.gifView.realImageView.image = playGif;
                            }
                            else {
                                message.downloadGif = YES;
                            }
                        }
                        
                        //    cell.gifView.alignTop = YES;
                        cell.gifView.alignLeft = YES;
                        cell.gifView.hidden = NO;
                        cell.audioIcon.hidden = YES;
                        cell.audioSlider.hidden = YES;
                        if ([message dataSize ] > 0) {
                            cell.messageSize.hidden = NO;
                            cell.messageSize.text = [NSString stringWithFormat:@"%d KB", (int) ceil(message.dataSize/1000.0)];
                        }
                        else {
                            cell.messageSize.hidden = YES;
                        }
                        
                        CGRect messageStatusFrame = cell.messageStatusLabel.frame;
                        if (ours) {
                            messageStatusFrame.origin.x = 22;
                        }
                        else {
                            messageStatusFrame.origin.x = 72;
                        }
                        
                        cell.messageStatusLabel.frame = messageStatusFrame;
                        
                        if (message.shareable) {
                            cell.shareableView.image = [UIImage imageNamed:@"ic_partial_secure"];
                        }
                        else {
                            cell.shareableView.image = [UIImage imageNamed:@"ic_secure"];
                        }
                        
                        [cell setMessage:message ourUsername:_username callback:nil retryAttempt:0];
                        
                    }
                    else {
                        if ([message.mimeType isEqualToString:MIME_TYPE_M4A]) {
                            CGRect messageStatusFrame = cell.messageStatusLabel.frame;
                            if (ours) {
                                [cell.audioIcon setImage: [UIImage imageNamed:@"ic_media_play"]];
                                messageStatusFrame.origin.x = 13;
                            }
                            else {
                                if (message.voicePlayed) {
                                    [cell.audioIcon setImage: [UIImage imageNamed:@"ic_media_play"]];
                                }
                                else {
                                    [cell.audioIcon setImage: [UIImage imageNamed:@"ic_media_played"]];
                                }
                                messageStatusFrame.origin.x = 63;
                                
                            }
                            cell.messageStatusLabel.frame = messageStatusFrame;
                            
                            if ([message dataSize ] > 0) {
                                cell.messageSize.hidden = NO;
                                cell.messageSize.text = [NSString stringWithFormat:@"%d KB", (int) ceil(message.dataSize/1000.0)];
                            }
                            else {
                                cell.messageSize.hidden = YES;
                            }
                            cell.shareableView.hidden = YES;
                            cell.messageLabel.hidden = YES;
                            cell.uiImageView.hidden = YES;
                            cell.gifView.hidden = YES;
                            cell.audioIcon.hidden = NO;
                            cell.audioSlider.hidden = NO;
                            
                            if (message.playVoice && [username isEqualToString: [self getCurrentTabName]]) {
                                [self ensureVoiceDelegate];
                                if (![_voiceDelegate isPlaying] && ![_voiceDelegate isRecording]) {
                                    [_voiceDelegate playVoiceMessage:message cell:cell];
                                }
                            }
                            else {
                                [cell setMessage:message
                                     ourUsername:_username
                                        progress:nil
                                       completed:nil
                                    retryAttempt:0
                                 ];
                            }
                            
                            [self ensureVoiceDelegate];
                            [_voiceDelegate attachCell:cell];
                        }
                        
                        else {
                            cell.messageLabel.hidden = NO;
                            cell.uiImageView.hidden = YES;
                            cell.gifView.hidden = YES;
                            cell.shareableView.hidden = YES;
                            cell.audioIcon.hidden = YES;
                            cell.audioSlider.hidden = YES;
                            cell.messageSize.hidden = YES;
                            CGRect messageStatusFrame = cell.messageStatusLabel.frame;
                            if (ours) {
                                messageStatusFrame.origin.x = 13;
                            }
                            else {
                                messageStatusFrame.origin.x = 63;
                            }
                            cell.messageStatusLabel.frame = messageStatusFrame;
                        }
                    }
                }
            }
            
            DDLogVerbose(@"returning cell, status text %@", cell.messageStatusLabel.text);
            return cell;
        }
        else {
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.backgroundColor = [UIColor clearColor];
            cell.userInteractionEnabled = NO;
            return cell;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger page = [_swipeView indexOfItemViewOrSubview:tableView];
    DDLogVerbose(@"selected, on page: %ld", (long)page);
    
    if (page == 0) {
        Friend * afriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource].friends objectAtIndex:indexPath.row];
        
        if (afriend && [afriend isFriend]) {
            NSString * friendname =[afriend name];
            [self showChat:friendname scroll: YES];
        }
        
        [_friendView deselectRowAtIndexPath:[_friendView indexPathForSelectedRow] animated:YES];
    }
    else {
        // if it's an image, open it in image viewer
        ChatDataSource * cds = [[[ChatManager sharedInstance] getChatController: _username] getDataSourceForFriendname:[self getCurrentTabName]];
        if (cds) {
            SurespotMessage * message = [cds.messages objectAtIndex:indexPath.row];
            
            if ([message.mimeType isEqualToString: MIME_TYPE_IMAGE]) {                
                [self disableMessageModeShowKeyboard:NO setResponders:YES];
                _imageMessage = message;
                MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
                browser.displayActionButton = NO; // Show action button to allow sharing, copying, etc (defaults to YES)
                browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
                browser.zoomPhotosToFill = YES; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
                browser.alwaysShowControls = YES;
                browser.navigationItem.title = NSLocalizedString(@"pan_and_zoom", nil);
                [browser setNavBarAppearance:NO tintColor:[UIUtils surespotBlue]];
                
                [self.navigationController setNavigationBarHidden:NO animated:YES];
                [self.navigationController pushViewController:browser animated:YES];

            }
            else {
                if ([message.mimeType isEqualToString: MIME_TYPE_M4A]) {
                    [self ensureVoiceDelegate];
                    MessageView * cell = (MessageView *) [tableView cellForRowAtIndexPath: indexPath];
                    
                    [_voiceDelegate playVoiceMessage: message cell:cell];
                }
                else {
                    if ([message.mimeType isEqualToString: MIME_TYPE_GIF_LINK]) {
                        
                        bool downloadGifs = [UIUtils getBoolPrefWithDefaultNoForUser:_username key:@"_user_pref_download_gifs"];
                        if (!downloadGifs) {
                            message.downloadGif = YES;
                            MessageView * cell = (MessageView *) [tableView cellForRowAtIndexPath: indexPath];
                            [cell setMessage:message ourUsername:_username callback:nil retryAttempt:0];
                            
                        }
                    }
                    
                }
            }
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

-(NSArray *) sortedAliasedChats {
    //account for aliases
    NSArray * allKeys = [_chats allKeys];
    
    NSMutableArray * aliasedChats = [NSMutableArray new];
    for (NSString * username in allKeys) {
        NSString * aliasedName = [[[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:username] nameOrAlias];
        UsernameAliasMap * t = [UsernameAliasMap new];
        t.username = username;
        t.alias = aliasedName;
        [aliasedChats addObject:t];
    }
    
    return [aliasedChats sortedArrayUsingComparator:^NSComparisonResult(UsernameAliasMap * obj1, UsernameAliasMap * obj2) {
        return [obj1.alias compare:obj2.alias options:NSCaseInsensitiveSearch];
    }];
}

-(NSArray *) sortedValues {
    NSArray * sortedMaps = [self sortedAliasedChats];
    NSMutableArray * sortedValues = [NSMutableArray new];
    for (UsernameAliasMap * map in sortedMaps) {
        [sortedValues addObject:[_chats objectForKey:map.username]];
    }
    return sortedValues;
}

-(void) loadChat:(NSString *) username show: (BOOL) show scroll: (BOOL) scroll availableId: (NSInteger) availableId availableControlId: (NSInteger) availableControlId {
    DDLogDebug(@"loadChat username: %@, show: %@", username, show ? @"YES" : @"NO");
    //get existing view if there is one
    UITableView * cView;
    @synchronized (_chats) {
        cView = [_chats objectForKey:username];
    }
    if (!cView) {
        
        [_tabLoading setObject:@"yourmama" forKey:username];
        
        __block NSInteger index = 0;
        @synchronized (_chats) {
            UIActivityIndicatorView * activityView = [[UIActivityIndicatorView alloc] initWithFrame:_swipeView.frame];
            [activityView startAnimating];
            [activityView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
            [activityView setColor:[self getThemeForegroundColor]];
            DDLogDebug(@"loadChat created activity view for username %@", username);
            [_chats setObject: activityView forKey:username];
            
            NSArray * sortedChats = [self sortedAliasedChats];
            for (int i=0;i<[sortedChats count];i++) {
                if ([[sortedChats[i] username] isEqualToString:username])  {
                    index = i+1;
                    break;
                }
            }
        }
        
        DDLogDebug(@"creatingindex: %ld", (long)index);
        [_swipeView loadViewAtIndex:index];
        [_swipeView updateItemSizeAndCount];
        [_swipeView updateScrollViewDimensions];
        
        
        if (show) {
            _scrollingTo = index;
            if (scroll) {
                [_swipeView scrollToPage:index duration:0.5];
            }
            else {
                [_swipeView setCurrentPage:index];
            }
            [[[ChatManager sharedInstance] getChatController: _username] setCurrentChat: username];
        }
        
        //create the data source
        [[[ChatManager sharedInstance] getChatController: _username] createDataSourceForFriendname:username availableId: availableId availableControlId:availableControlId callback:^(id result) {
            DDLogDebug(@"data source created for user: %@", username);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UITableView * chatView = [[UITableView alloc] initWithFrame:_swipeView.frame];
                
                [chatView setDelegate:self];
                [chatView setDataSource: self];
                [chatView registerNib:[UINib nibWithNibName:@"OurMessageCell" bundle:nil] forCellReuseIdentifier:@"OurMessageView"];
                [chatView registerNib:[UINib nibWithNibName:@"TheirMessageCell" bundle:nil] forCellReuseIdentifier:@"TheirMessageView"];
                [chatView setBackgroundColor:[UIColor clearColor]];
                [chatView setScrollsToTop:NO];
                [chatView setDirectionalLockEnabled:YES];
                [chatView setSeparatorColor: [UIUtils surespotSeparatorGrey]];
                [chatView setSeparatorInset:UIEdgeInsetsZero];
                [self addLongPressGestureRecognizer:chatView];
                
                // setup pull-to-refresh
                __weak UITableView *weakView = chatView;
                [chatView addPullToRefreshWithActionHandler:^{
                    
                    [[[ChatManager sharedInstance] getChatController: _username] loadEarlierMessagesForUsername: username callback:^(id result) {
                        if (result) {
                            NSInteger resultValue = [result integerValue];
                            if (resultValue == 0 || resultValue == NSIntegerMax) {
                                [UIUtils showToastKey:@"all_messages_loaded"];
                            }
                            else {
                                DDLogVerbose(@"loaded %@ earlier messages for user: %@", result, username);
                                [self updateTableView:weakView withNewRowCount:[result intValue]];
                            }
                        }
                        else {
                            [UIUtils showToastKey:@"loading_earlier_messages_failed"];
                        }
                        
                        [weakView.pullToRefreshView stopAnimating];
                        
                    }];
                }];
                
                DDLogDebug(@"removing tab loading for username: %@", username);
                [_chats setObject:chatView forKey:username];
                [_tabLoading removeObjectForKey:username];
                [_swipeView loadViewAtIndex:index];
                [chatView reloadData];
                DDLogVerbose(@"loadChat scrolling table view to bottom for username: %@", username);
                [self scrollTableViewToBottom:chatView animated: NO];
                //  @synchronized (_needsScroll) {
                //     DDLogVerbose(@"setting needs scroll for %@", username);
                //  [_needsScroll setObject:@"yourmama" forKey:username];
                //    [_bottomIndexPaths removeObjectForKey:username];
                //  }
            });
        }];
    }
    
    else {
        if (show) {
            [[[ChatManager sharedInstance] getChatController: _username] setCurrentChat: username];
            NSInteger index=0;
            @synchronized (_chats) {
                
                NSArray * sortedChats = [self sortedAliasedChats];
                for (int i=0;i<[sortedChats count];i++) {
                    if ([[sortedChats[i] username] isEqualToString:username])  {
                        index = i+1;
                        break;
                    }
                }
            }
            
            NSInteger currentIndex = [_swipeView currentItemIndex];
            DDLogDebug(@"loadChat, currentIndex: %ld", (long)index);
            
            if (currentIndex != index) {
                DDLogDebug(@"scrolling to index: %ld", (long)index);
                _scrollingTo = index;
                
                [_swipeView scrollToPage:index duration:0.5];
            }
            HomeDataSource * hds = [[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource];
            if ([hds hasAnyNewMessages]) {
                //   [self scrollTableViewToBottom:cView animated:NO];
            }
            
        }
    }
}

-(void) showChat:(NSString *) username scroll: (BOOL) scroll {
    DDLogVerbose(@"showChat, %@", username);
    
    Friend * afriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:username];
    
    [self loadChat:username show:YES scroll: scroll availableId:[afriend availableMessageId] availableControlId:[afriend availableMessageControlId]];
    //   [_textField resignFirstResponder];
}



- (BOOL) handleTextAction {
    return [self handleTextActionResign:YES];
}

- (BOOL) handleTextActionResign: (BOOL) resign {
    if (![self getCurrentTabName]) {
        NSString * text = _inviteTextView.text;
        
        if ([text length] > 0) {
            
            NSString * loggedInUser = _username;
            if ([text isEqualToString:loggedInUser]) {
                [UIUtils showToastKey:@"friend_self_error"];
                return YES;
            }
            
            
            [[[ChatManager sharedInstance] getChatController: _username] inviteUser:text];
            [_inviteTextView setText:nil];
            [self updateTabChangeUI];
            return YES;
        }
        else {
            if (resign) {
                [self resignAllResponders];
            }
            return NO;
        }
        
    }
    else {
        NSString * text = _messageTextView.text;
        
        if ([text length] > 0) {
            
            [self send];
            return YES;
        }
        
        else {
            if (resign) {
                [self resignAllResponders];
            }
            return NO;
        }
    }
    
    
}


- (void) send {
    
    NSString* message = _messageTextView.text;
    
    if ([UIUtils stringIsNilOrEmpty:message]) return;
    
    NSString * friendname = [self getCurrentTabName];
    
    Friend * afriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName: friendname];
    if ([afriend isDeleted]) {
        return;
    }
    
    [[[ChatManager sharedInstance] getChatController: _username] sendTextMessage: message toFriendname:friendname];
    [_messageTextView setText:nil];
    
    [self updateTabChangeUI];
}


//if we're going to chat tab from home tab and keyboard is showing
//become the first esponder so we're not typing in the invite field
//thinking we're typing in the text field
-(void) updateKeyboardState: (BOOL) goingHome {
    //    DDLogInfo(@"updateKeyboardState, goingHome: %hhd", (char)goingHome);
    if (goingHome) {
        [self resignAllResponders];
    }
    else {
        if ([_inviteTextView isFirstResponder]) {
            [_messageTextView becomeFirstResponder];
        }
    }
}

-(void) updateTabChangeUI {
    
    
    //calculate if we need to expand so we can show buttons on animation completion
    BOOL expand = [self shouldExpand];
    DDLogVerbose(@"updateTabChangeUI, shouldExpand: %d", expand);
    if (expand && _collapsed) {
        [self expand];
        return;
        
    }
    
    if (![self getCurrentTabName]) {
        [_theButton setImage:[UIImage imageNamed:@"add_friend"] forState:UIControlStateNormal];
        _messageTextView.hidden = YES;
        
        _inviteTextView.hidden = NO;
        _qrButton.hidden = NO;
        _gifButton.hidden = YES;
        _cameraButton.hidden = YES;
        _galleryButton.hidden = YES;
        _expandButton.hidden = YES;
        
        _giphySearchTextView.hidden = YES;
        _giphyImage.hidden = YES;
        _theButton.hidden = NO;
        
    }
    else {
        _qrButton.hidden = YES;
        _inviteTextView.hidden = YES;
        Friend *afriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:[self getCurrentTabName]];
        if (afriend.isDeleted) {
            [_theButton setImage:[UIImage imageNamed:@"ic_menu_home"] forState:UIControlStateNormal];
            _messageTextView.hidden = YES;
            _gifButton.hidden = YES;
            _cameraButton.hidden = YES;
            _galleryButton.hidden = YES;
            _giphySearchTextView.hidden = YES;
            _giphyImage.hidden = YES;
            _theButton.hidden = NO;
            _expandButton.hidden = YES;
        }
        else {
            switch (_currentMode) {
                case MessageModeNone:
                    _messageTextView.hidden = NO;
                    _expandButton.hidden = YES;
                    _gifButton.hidden = NO;
                    _gifButton.selected = NO;
                    _cameraButton.hidden = NO;
                    _cameraButton.selected = NO;
                    _galleryButton.hidden = NO;
                    _galleryButton.selected = NO;
                    _giphySearchTextView.hidden = YES;
                    _giphyImage.hidden = YES;
                    _theButton.hidden = NO;
                    _theButton.selected = NO;
                    break;
                case MessageModeKeyboard:
                    _messageTextView.hidden = NO;
                    _expandButton.hidden = NO;
                    _expandButton.selected = YES;
                    _gifButton.selected = NO;
                    _gifButton.hidden = YES;
                    _cameraButton.hidden = YES;
                    _galleryButton.hidden = YES;
                    _galleryButton.selected = NO;
                    _giphySearchTextView.hidden = YES;
                    _giphyImage.hidden = YES;
                    _theButton.hidden = NO;
                    _theButton.selected = NO;
                    break;
                    
                case MessageModeGIF:
                    _messageTextView.hidden = YES;
                    _expandButton.hidden = YES;
                    _gifButton.hidden = NO;
                    _gifButton.selected = YES;
                    _cameraButton.hidden = YES;
                    _galleryButton.hidden = YES;
                    _galleryButton.selected = NO;
                    _giphySearchTextView.hidden = NO;
                    _giphyImage.hidden = NO;
                    _theButton.hidden = YES;
                    break;
                case MessageModeGallery:
                    _messageTextView.hidden = NO;
                    _expandButton.hidden = YES;
                    _gifButton.hidden = NO;
                    _gifButton.selected = NO;
                    _cameraButton.hidden = NO;
                    _galleryButton.hidden = NO;
                    _galleryButton.selected = YES;
                    _giphySearchTextView.hidden = YES;
                    _giphyImage.hidden = YES;
                    _theButton.hidden = NO;
                    break;
            }
            
            if ([_messageTextView.text length] > 0) {
                [_theButton setImage:[UIImage imageNamed:@"send"] forState:UIControlStateNormal];
            }
            else {
                BOOL disableVoice = [UIUtils getBoolPrefWithDefaultNoForUser:_username key:@"_user_pref_disable_voice"];
                if (disableVoice) {
                    [_theButton setImage:[UIImage imageNamed:@"ic_menu_home"] forState:UIControlStateNormal];
                }
                else {
                    [_theButton setImage:[UIImage imageNamed:@"mic"] forState:UIControlStateNormal];
                }
            }
        }
    }
    
    _theButton.selected = NO;
    
    if (expand) {
        [self expand];
    }
    else {
        [self collapse];
    }
}

-(void) updateTableView: (UITableView *) tableView withNewRowCount : (int) rowCount
{
    //Save the tableview content offset
    CGPoint tableViewOffset = [tableView contentOffset];
    
    //compute the height change
    int heightForNewRows = 0;
    
    for (NSInteger i = 0; i < rowCount; i++) {
        NSIndexPath *tempIndexPath = [NSIndexPath indexPathForRow:i inSection:0];
        heightForNewRows += [self tableView:tableView heightForRowAtIndexPath: tempIndexPath];
    }
    
    tableViewOffset.y += heightForNewRows;
    [tableView reloadData];
    [tableView setContentOffset:tableViewOffset animated:NO];
}


- (void)refreshMessages:(NSNotification *)notification {
    NSString * username = [notification.object objectForKey:@"username"];
    if ([_tabLoading objectForKey:username]) {
        return;
    }
    
    BOOL scroll = [[notification.object objectForKey:@"scroll"] boolValue];
    DDLogVerbose(@"refreshMessages, username: %@, currentchat: %@, scroll: %d", username, [self getCurrentTabName], scroll);
    
    UITableView * tableView;
    @synchronized (_chats) {
        tableView = [_chats objectForKey:username];
    }
    
    if (tableView) {
        [tableView reloadData];
    }
    
    if (scroll) {
        if ([username isEqualToString: [self getCurrentTabName]]) {
            @synchronized (_needsScroll) {
                [_needsScroll removeObjectForKey:username];
            }
            
            if (tableView) {
                DDLogVerbose(@"refreshMessages calling scrollTableViewToBottom");
                [self scrollTableViewToBottom: tableView];
            }
        }
        else {
            @synchronized (_needsScroll) {
                DDLogVerbose(@"refreshMessages setting needs scroll for %@", username);
                [_needsScroll setObject:@"yourmama" forKey:username];
                [_bottomIndexPaths removeObjectForKey:username];
            }
        }
    }
}

- (void) scrollTableViewToBottom: (UITableView *) tableView {
    [self scrollTableViewToBottom:tableView animated:YES];
}

- (void) scrollTableViewToBottom: (UITableView *) tableView animated: (BOOL) animated {
    DDLogVerbose(@"scrollTableViewToBottom, delta: %g, tableView.contentOffset.y: %f, (tableView.contentSize.height - tableView.frame.size.height): %f", tableView.contentOffset.y - (tableView.contentSize.height - tableView.frame.size.height), tableView.contentOffset.y, (tableView.contentSize.height - tableView.frame.size.height));
    
    NSInteger numRows = [tableView numberOfRowsInSection:0] - 1;
    DDLogVerbose(@"scrollTableViewToBottom, numRows: %ld", (long)numRows);
    
    if (numRows > 0) {
        DDLogVerbose(@"scrollTableViewToBottom request scroll to row: %ld, animated: %d", (long)numRows, animated);
        NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:numRows inSection:0];
        DDLogVerbose(@"scrollTableViewToBottom actual bottom row: %ld", (long)scrollIndexPath.row);
        if ([tableView numberOfSections] > scrollIndexPath.section && [tableView numberOfRowsInSection:0] > scrollIndexPath.row ) {
            DDLogVerbose(@"scrollTableViewToBottom scrolling to row: %ld, animated: %d", (long)numRows, animated);
            [tableView scrollToRowAtIndexPath:scrollIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:animated];
        }
    }
}

- (void) scrollTableViewToCell: (UITableView *) tableView  indexPath: (NSIndexPath *) indexPath {
    DDLogVerbose(@"scrolling to cell: %@", indexPath);
    if ( [tableView numberOfSections] > indexPath.section && [tableView numberOfRowsInSection:0] > indexPath.row ) {
        [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }
}

- (void)refreshHome:(NSNotification *)notification
{
    DDLogVerbose(@"refreshHome");
    
    if (_friendView) {
        [_friendView reloadData];
    }
    
}


-(void) removeFriend: (Friend *) afriend {
    [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] removeFriend:afriend withRefresh:YES];
}


- (NSString *)stringFromDate:(NSDate *)date
{
    __block NSString *string = nil;
    dispatch_sync(_dateFormatQueue, ^{
        //strip out commas
        string = [[_dateFormatter stringFromDate:date ] stringByReplacingOccurrencesOfString:@"," withString:@""];
    });
    return string;
}

-(void) sendImageToFriendname: (NSString *) friendname viewController: (UIViewController *) viewController {
    if (friendname) {
        
        Friend * theFriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:friendname];
        if ([theFriend isFriend] && ![theFriend isDeleted]) {
            
            if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) {
                _swipeView.suppressLayoutSubviews = YES;
            }
            _imageDelegate = [[ImageDelegate alloc]
                              initWithUsername:_username
                              ourVersion:[[IdentityController sharedInstance] getOurLatestVersion: _username]
                              theirUsername:friendname];
            _imageDelegate.delegate = self;
            [_galleryView removeFromSuperview];
            [self disableMessageModeShowKeyboard:NO setResponders:YES];
            [ImageDelegate startImageSelectControllerFromViewController:viewController usingDelegate:_imageDelegate];
        }
    }
}

-(REMenu *) createMenuMenu {
    //menu menu
    NSMutableArray * menuItems = [NSMutableArray new];
    
    if ([self getCurrentTabName]) {
        REMenuItem * closeTabItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_close_tab", nil) image:[UIImage imageNamed:@"ic_menu_end_conversation"] highlightedImage:nil action:^(REMenuItem * item){
            [self closeTab];
        }];
        
        
        
        [menuItems addObject:closeTabItem];
        
        REMenuItem * deleteAllItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_all_messages", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
            //confirm if necessary
            
            BOOL confirm = [UIUtils getBoolPrefWithDefaultYesForUser:_username key:@"_user_pref_delete_all_messages"];
            if (confirm) {
                NSString * okString = NSLocalizedString(@"ok", nil);
                [UIAlertView showWithTitle:NSLocalizedString(@"delete_all_title", nil)
                                   message:NSLocalizedString(@"delete_all_confirmation", nil)
                         cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                         otherButtonTitles:@[okString]
                                  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                      if (buttonIndex == [alertView cancelButtonIndex]) {
                                          DDLogVerbose(@"delete cancelled");
                                      } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:okString]) {
                                          [[[ChatManager sharedInstance] getChatController: _username] deleteMessagesForFriend: [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:[self getCurrentTabName]]];
                                      };
                                      
                                  }];
            }
            else {
                
                [[[ChatManager sharedInstance] getChatController: _username] deleteMessagesForFriend: [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:[self getCurrentTabName]]];
            }
            
        }];
        
        [menuItems addObject:deleteAllItem];
    }
    else {
        //close all tabs only appears on home tab
        REMenuItem * closeAllTabsItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_close_all_tabs", nil) image:[UIImage imageNamed:@"ic_menu_end_conversation"] highlightedImage:nil action:^(REMenuItem * item){
            [self closeAllTabs];
        }];
        
        [menuItems addObject: closeAllTabsItem];
    }
    
    REMenuItem * shareItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"share_invite_link", nil) image:[UIImage imageNamed:@"blue_heart"] highlightedImage:nil action:^(REMenuItem * menuitem){
        
        _progressView = [LoadingView showViewKey:@"invite_progress_text"];
        NSString * inviteUrl = [NSString stringWithFormat:@"https://invite.surespot.me/autoinvite/%@%@",
                                [_username stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], @"/ios"];
        
        
        [[[NetworkManager sharedInstance] getNetworkController:nil] getShortUrl:inviteUrl callback:^(id shortUrl) {
            [_progressView removeView];
            NSString * text = [NSString stringWithFormat:NSLocalizedString(@"external_invite_message", nil), shortUrl];
            
            UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
            
            controller.excludedActivityTypes = @[UIActivityTypePostToWeibo,
                                                 UIActivityTypePrint,
                                                 UIActivityTypeAssignToContact,
                                                 UIActivityTypeSaveToCameraRoll,
                                                 UIActivityTypeAddToReadingList,
                                                 UIActivityTypePostToFlickr,
                                                 UIActivityTypePostToVimeo,
                                                 UIActivityTypePostToTencentWeibo,
                                                 UIActivityTypeAirDrop];
            
            //does weird shit with the keyboard
            _suspendKeyboardListeners = YES;
            [controller  setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
                _suspendKeyboardListeners = NO;
            }];
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            {
                [self presentViewController:controller animated:YES completion:nil];
            }
            //if iPad
            else
            {
                // Change Rect to position Popover
                _popover = [[UIPopoverController alloc] initWithContentViewController:controller];
                _popover.delegate = self;
                [_popover presentPopoverFromRect:CGRectMake(self.view.frame.size.width/2, self.view.frame.size.height/2, 0, 0) inView:self.view permittedArrowDirections:0 animated:YES];
            }
        }];
    }];
    [menuItems addObject:shareItem];
    
    
    
    REMenuItem * pwylItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"pay_what_you_like", nil) image:
                             [UIImage imageNamed:@"heart"]
                                             highlightedImage:nil action:^(REMenuItem * item){
                                                 [[PurchaseDelegate sharedInstance] showPwylViewForController:self];
                                                 
                                                 
                                             }];
    [menuItems addObject:pwylItem];
    
    REMenuItem * settingsItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"settings", nil) image:[UIImage imageNamed:@"ic_menu_preferences"] highlightedImage:nil action:^(REMenuItem * item){
        [self showSettings];
        
    }];
    
    [menuItems addObject:settingsItem];
    
    REMenuItem * logoutItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"logout", nil) image:[UIImage imageNamed:@"ic_lock_power_off"] highlightedImage:nil action:^(REMenuItem * item){
        //confirm if necessary
        if ([UIUtils confirmLogout]) {
            NSString * okString = NSLocalizedString(@"ok", nil);
            [UIAlertView showWithTitle:NSLocalizedString(@"confirm_logout_title", nil)
                               message:NSLocalizedString(@"confirm_logout_message", nil)
                     cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                     otherButtonTitles:@[okString]
                              tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                  if (buttonIndex == [alertView cancelButtonIndex]) {
                                      DDLogVerbose(@"logout cancelled");
                                  } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:okString]) {
                                      [self logout];
                                  };
                                  
                              }];
            
            
        }
        else {
            [self logout];
        }
        
    }];
    [menuItems addObject:logoutItem];
    
    return [self createMenu: menuItems];
}

-(REMenu *) createMenu: (NSArray *) menuItems {
    REMenu * menu = [UIUtils createMenu:menuItems closeCompletionHandler:^{
        _menu = nil;
        NSString * getCurrentChat = [self getCurrentTabName];
        if (getCurrentChat) {
            id currentTableView =[_chats objectForKey:getCurrentChat];
            if ([currentTableView respondsToSelector:@selector(deselectRowAtIndexPath:animated:)]) {
                [currentTableView deselectRowAtIndexPath:[currentTableView indexPathForSelectedRow] animated:YES];
            }
        }
        else {
            [_friendView deselectRowAtIndexPath:[_friendView indexPathForSelectedRow] animated:YES];
        }
        _swipeView.userInteractionEnabled = YES;
        [self setBackButtonEnabled:YES];
        [self updateTabChangeUI];
    }];
    
    [menu setBackgroundView:[self createMenuAlpha]];
    return menu;
}


-(REMenu *) createHomeMenuFriend: (Friend *) thefriend {
    //home menu
    NSMutableArray * menuItems = [NSMutableArray new];
    UsernameAliasMap * map = [UsernameAliasMap new];
    map.username = thefriend.name;
    map.alias = thefriend.aliasPlain;
    
    
    NSString * aliasName =[UIUtils buildAliasStringForUsername:[thefriend name] alias:[thefriend aliasPlain]];
    REMenuItem * titleItem = [[REMenuItem alloc] initWithTitle: nil image:nil highlightedImage:nil action:nil];
    
    [titleItem setSubtitle:aliasName];
    //  [titleItem setTitleEnabled:NO];
    
    [menuItems addObject:titleItem];
    
    if ([thefriend isFriend]) {
        //can't prevent notification showing in service extension so comment this out until or if one day we can
        //        if ([thefriend muted]) {
        //            REMenuItem * unmuteItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"unmute", nil) image:[UIImage imageNamed:@"ic_volume_on"] highlightedImage:nil action:^(REMenuItem * item){
        //                [[[ChatManager sharedInstance] getChatController: _username] unmute: thefriend];
        //            }];
        //            [menuItems addObject:unmuteItem];
        //
        //        }
        //        else {
        //            REMenuItem * muteItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"mute", nil) image:[UIImage imageNamed:@"ic_volume_off"] highlightedImage:nil action:^(REMenuItem * item){
        //                [[[ChatManager sharedInstance] getChatController: _username] mute: thefriend];
        //            }];
        //            [menuItems addObject:muteItem];
        //        }
        //
        if ([thefriend isChatActive]) {
            REMenuItem * closeTabHomeItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_close_tab", nil) image:[UIImage imageNamed:@"ic_menu_end_conversation"] highlightedImage:nil action:^(REMenuItem * item){
                [self closeTabName: thefriend.name];
            }];
            [menuItems addObject:closeTabHomeItem];
        }
        
        
        REMenuItem * deleteAllHomeItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_all_messages", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
            
            //confirm if necessary
            BOOL confirm = [UIUtils getBoolPrefWithDefaultYesForUser:_username key:@"_user_pref_delete_all_messages"];
            if (confirm) {
                NSString * okString = NSLocalizedString(@"ok", nil);
                [UIAlertView showWithTitle:NSLocalizedString(@"delete_all_title", nil)
                                   message:NSLocalizedString(@"delete_all_confirmation", nil)
                         cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                         otherButtonTitles:@[okString]
                                  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                      if (buttonIndex == [alertView cancelButtonIndex]) {
                                          DDLogVerbose(@"delete cancelled");
                                      } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:okString]) {
                                          [[[ChatManager sharedInstance] getChatController: _username] deleteMessagesForFriend: thefriend];
                                      };
                                      
                                  }];
            }
            else {
                [[[ChatManager sharedInstance] getChatController: _username] deleteMessagesForFriend: thefriend];
            }
        }];
        [menuItems addObject:deleteAllHomeItem];
        
        
        if (![thefriend isDeleted]) {
            REMenuItem * fingerprintsItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"verify_key_fingerprints", nil) image:[UIImage imageNamed:@"fingerprint_zoom"] highlightedImage:nil action:^(REMenuItem * item){
                //cameraUI
                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                    _popover = [[UIPopoverController alloc] initWithContentViewController:[[KeyFingerprintViewController alloc]                                                                                                            initWithNibName:@"KeyFingerprintView" ourUsername: _username usernameMap:map]];
                    _popover.delegate = self;
                    CGFloat x = self.view.bounds.size.width;
                    CGFloat y =self.view.bounds.size.height;
                    DDLogVerbose(@"setting popover x, y to: %f, %f", x/2,y/2);
                    [_popover setPopoverContentSize:CGSizeMake(320, 480) animated:YES];
                    [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
                    
                } else {
                    
                    
                    [self.navigationController pushViewController:[[KeyFingerprintViewController alloc] initWithNibName:@"KeyFingerprintView" ourUsername:_username usernameMap:map] animated:YES];
                }
                
            }];
            [menuItems addObject:fingerprintsItem];
            
            
            if (![thefriend hasFriendImageAssigned]) {
                REMenuItem * selectImageItem = [[REMenuItem alloc]
                                                initWithTitle:NSLocalizedString(@"menu_assign_image", nil)
                                                image:[UIImage imageNamed:@"ic_menu_gallery"]
                                                highlightedImage:nil
                                                action:^(REMenuItem * item){
                                                    
                                                    _imageDelegate = [[ImageDelegate alloc]
                                                                      initWithUsername:_username
                                                                      ourVersion:[[IdentityController sharedInstance] getOurLatestVersion: _username]
                                                                      theirUsername:thefriend.name];
                                                    
                                                    [ImageDelegate startFriendImageSelectControllerFromViewController:self usingDelegate:_imageDelegate];
                                                    
                                                    
                                                }];
                [menuItems addObject:selectImageItem];
            }
            else {
                REMenuItem * removeImageItem = [[REMenuItem alloc]
                                                initWithTitle:NSLocalizedString(@"menu_remove_friend_image", nil)
                                                image:[UIImage imageNamed:@"ic_menu_gallery"]
                                                highlightedImage:nil
                                                action:^(REMenuItem * item){
                                                    [[[ChatManager sharedInstance] getChatController: _username] removeFriendImage:[thefriend name] callbackBlock:^(id result) {
                                                        BOOL success = [result boolValue];
                                                        if (!success) {
                                                            [UIUtils showToastKey:@"could_not_remove_friend_image" duration:1];
                                                        }
                                                    }];
                                                    
                                                    
                                                }];
                [menuItems addObject:removeImageItem];
                
            }
            
            if (![thefriend hasFriendAliasAssigned]) {
                REMenuItem * assignAliasItem = [[REMenuItem alloc]
                                                initWithTitle:NSLocalizedString(@"menu_assign_alias", nil)
                                                image:[UIImage imageNamed:@"ic_menu_friendslist"]
                                                highlightedImage:nil
                                                action:^(REMenuItem * item){
                                                    
                                                    //show alert view to get password
                                                    UIAlertView * av = [[UIAlertView alloc]
                                                                        initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"enter_alias", nil), [thefriend name]]
                                                                        message:[NSString stringWithFormat:NSLocalizedString(@"enter_alias_for", nil), [thefriend name]]
                                                                        delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                                                                        otherButtonTitles:NSLocalizedString(@"ok", nil), nil];
                                                    av.alertViewStyle = UIAlertViewStylePlainTextInput;
                                                    av.shouldEnableFirstOtherButtonBlock = ^BOOL(UIAlertView * alertView) {
                                                        return ([[[alertView textFieldAtIndex:0] text] length] <= 20);
                                                    };
                                                    av.tapBlock =^(UIAlertView *alertView, NSInteger buttonIndex) {
                                                        if (buttonIndex == alertView.firstOtherButtonIndex) {
                                                            NSString * alias = [[alertView textFieldAtIndex:0] text];
                                                            if (![UIUtils stringIsNilOrEmpty:alias]) {
                                                                DDLogVerbose(@"entered alias: %@", alias);
                                                                [[[ChatManager sharedInstance] getChatController: _username] assignFriendAlias:alias toFriendName:[thefriend name] callbackBlock:^(id result) {
                                                                    BOOL success = [result boolValue];
                                                                    if (!success) {
                                                                        [UIUtils showToastKey:@"could_not_assign_friend_alias" duration:1];
                                                                    }
                                                                }];
                                                            }
                                                        }
                                                    };
                                                    
                                                    [[av textFieldAtIndex:0] setText:[thefriend name]];
                                                    [av show];
                                                }];
                [menuItems addObject:assignAliasItem];
            }
            else {
                REMenuItem * removeAliasItem = [[REMenuItem alloc]
                                                initWithTitle:NSLocalizedString(@"menu_remove_friend_alias", nil)
                                                image:[UIImage imageNamed:@"ic_menu_friendslist"]
                                                highlightedImage:nil
                                                action:^(REMenuItem * item){
                                                    [[[ChatManager sharedInstance] getChatController: _username] removeFriendAlias:[thefriend name] callbackBlock:^(id result) {
                                                        BOOL success = [result boolValue];
                                                        if (!success) {
                                                            [UIUtils showToastKey:@"could_not_remove_friend_alias" duration:1];
                                                        }
                                                    }];
                                                }];
                [menuItems addObject:removeAliasItem];
            }
        }
    }
    
    if (![thefriend isInviter]) {
        
        REMenuItem * deleteFriendItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_friend", nil) image:[UIImage imageNamed:@"ic_menu_blocked_user"] highlightedImage:nil action:^(REMenuItem * item){
            
            NSString * okString = NSLocalizedString(@"ok", nil);
            [UIAlertView showWithTitle:NSLocalizedString(@"menu_delete_friend", nil)
                               message:[NSString stringWithFormat: NSLocalizedString(@"delete_friend_confirmation", nil), [UIUtils buildAliasStringForUsername:thefriend.name alias:thefriend.aliasPlain]]
                     cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                     otherButtonTitles:@[okString]
                              tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                  if (buttonIndex == [alertView cancelButtonIndex]) {
                                      DDLogVerbose(@"delete cancelled");
                                  } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:okString]) {
                                      [[[ChatManager sharedInstance] getChatController: _username] deleteFriend: thefriend];
                                  };
                              }];
            
            
            
        }];
        [menuItems addObject:deleteFriendItem];
    }
    
    
    return [self createMenu: menuItems];
}

-(REMenu *) createChatMenuMessage: (SurespotMessage *) message {
    BOOL ours = [ChatUtils isOurMessage:message ourUsername:_username];
    NSMutableArray * menuItems = [NSMutableArray new];
    
    //copy
    if ([message.mimeType isEqualToString:MIME_TYPE_TEXT] && message.plainData) {
        REMenuItem * copyItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_copy", nil) image:[UIImage imageNamed:@"ic_menu_copy"] highlightedImage:nil action:^(REMenuItem * item){
            
            [[UIPasteboard generalPasteboard]  setString: message.plainData];
            
            //            [UIUtils showToastKey:@"message" duration:2];
            
        }];
        [menuItems addObject:copyItem];
        
    }
    
    if ([message.mimeType isEqualToString:MIME_TYPE_IMAGE]) {
        //if it's our message and it's been sent we can change lock status
        if (message.serverid > 0 && ours) {
            UIImage * image = nil;
            NSString * title = nil;
            if (!message.shareable) {
                title = NSLocalizedString(@"menu_unlock", nil);
                image = [UIImage imageNamed:@"ic_menu_partial_secure"];
            }
            else {
                title = NSLocalizedString(@"menu_lock", nil);
                image = [UIImage imageNamed:@"ic_menu_secure"];
            }
            
            REMenuItem * shareItem = [[REMenuItem alloc] initWithTitle:title image:image highlightedImage:nil action:^(REMenuItem * item){
                [[[ChatManager sharedInstance] getChatController: _username] toggleMessageShareable:message];
                
            }];
            
            [menuItems addObject:shareItem];
        }
        
        //allow saving to gallery if it's unlocked, or it's ours
        if (message.shareable && !ours) {
            REMenuItem * saveItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"save_to_photos", nil) image:[UIImage imageNamed:@"ic_menu_save"] highlightedImage:nil action:^(REMenuItem * item){
                if (message.shareable && !ours) {
                    [SDWebImageManager.sharedManager downloadWithURL: [NSURL URLWithString:message.data]
                                                            mimeType: MIME_TYPE_IMAGE
                                                         ourUsername: _username
                                                          ourVersion: [message getOurVersion: _username]
                                                       theirUsername: [message getOtherUser: _username]
                                                        theirVersion: [message getTheirVersion: _username]
                                                                  iv: [message iv]
                                                              hashed: [message hashed]
                                                             options: (SDWebImageOptions) 0
                                                            progress:nil completed:^(id data, NSString * mimeType, NSError *error, SDImageCacheType cacheType, BOOL finished)
                     {
                         
                         if (error) {
                             [UIUtils showToastKey:@"error_saving_image_to_photos"];
                         }
                         else {
                             [UIUtils saveImage:data completionHandler:^(NSString *localIdentifier) {
                                 if (!localIdentifier) {
                                     [UIUtils showToastKey:@"error_saving_image_to_photos" duration:2];
                                 }
                                 else {
                                     [UIUtils showToastKey:@"image_saved_to_photos"];
                                 }
                             }];
                         }
                     }];
                }
                else {
                    [UIUtils showToastKey:@"error_saving_image_to_photos_locked" duration:2];
                }
            }];
            [menuItems addObject:saveItem];
        }
    }
    
    //can always delete
    REMenuItem * deleteItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_message", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
        
        //confirm if necessary
        BOOL confirm = [UIUtils getBoolPrefWithDefaultYesForUser:_username key:@"_user_pref_delete_message"];
        if (confirm) {
            NSString * okString = NSLocalizedString(@"ok", nil);
            [UIAlertView showWithTitle:NSLocalizedString(@"delete_message", nil)
                               message:NSLocalizedString(@"delete_message_confirmation_title", nil)
                     cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                     otherButtonTitles:@[okString]
                              tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                  if (buttonIndex == [alertView cancelButtonIndex]) {
                                      DDLogVerbose(@"delete cancelled");
                                  } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:okString]) {
                                      [self deleteMessage: message];
                                  };
                                  
                              }];
        }
        else {
            
            [self deleteMessage: message];
        }
        
        
    }];
    
    [menuItems addObject:deleteItem];
    return [self createMenu: menuItems];
    
}

-(void)tableLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    NSInteger _menuPage = _swipeView.currentPage;
    UITableView * currentView = _menuPage == 0 ? _friendView : [[self sortedValues] objectAtIndex:_menuPage-1];
    
    CGPoint p = [gestureRecognizer locationInView:currentView];
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        NSIndexPath *indexPath = [currentView indexPathForRowAtPoint:p];
        if (indexPath == nil) {
            DDLogVerbose(@"long press on table view at page %ld but not on a row", (long)_menuPage);
        }
        else {
            
            
            [currentView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            [self showMenuForPage: _menuPage indexPath: indexPath];
            DDLogVerbose(@"long press on table view at page %ld, row %ld", (long)_menuPage, (long)indexPath.row);
        }
    }
}

-(void) deleteMessage: (SurespotMessage *) message {
    if (message) {
        DDLogVerbose(@"taking action for chat iv: %@", message.iv);
        [[[ChatManager sharedInstance] getChatController: _username] deleteMessage: message];
    }
}

-(UIView *) createMenuAlpha {
    UIView * view = [[UIView alloc] initWithFrame:self.bgImageView.frame];
    [view setBackgroundColor:[UIColor blackColor]];
    return view;
}

-(void) showMenuMenu {
    if (!_menu) {
        _menu = [self createMenuMenu];
        if (_menu) {
            [self disableMessageModeShowKeyboard:NO setResponders:YES];
            _swipeView.userInteractionEnabled = NO;
            [self setBackButtonEnabled:NO];
            [_menu showSensiblyInView:self.view];
        }
    }
    else {
        [_menu close];
    }
}

-(void) showMenuForPage: (NSInteger) page indexPath: (NSIndexPath *) indexPath {
    if (!_menu) {
        
        if (page == 0) {
            NSArray * friends = [[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource].friends;
            if (indexPath.row < [friends count]) {
                Friend * afriend = [friends objectAtIndex:indexPath.row];
                _menu = [self createHomeMenuFriend:afriend];
            }
        }
        
        else {
            NSString * name = [self nameForPage:page];
            NSArray * messages =[[[ChatManager sharedInstance] getChatController: _username] getDataSourceForFriendname: name].messages;
            if (indexPath.row < messages.count) {
                SurespotMessage * message =[messages objectAtIndex:indexPath.row];
                _menu = [self createChatMenuMessage:message];
            }
        }
        
        if (_menu) {
            [self disableMessageModeShowKeyboard:NO setResponders:YES];
            _swipeView.userInteractionEnabled = NO;
            [self setBackButtonEnabled:NO];
            [_menu showSensiblyInView:self.view];
        }
    }
    else {
        [_menu close];
    }
}

- (void)deleteFriend:(NSNotification *)notification
{
    NSArray * data =  notification.object;
    
    NSString * name  =[data objectAtIndex:0];
    BOOL ideleted = [[data objectAtIndex:1] boolValue];
    
    if (ideleted) {
        [self closeTabName:name];
    }
    else {
        [self updateTabChangeUI];
        if ([name isEqualToString:[self getCurrentTabName]]) {
            [_messageTextView resignFirstResponder];
        }
    }
}

-(void) closeTabName: (NSString *) name {
    if (name) {
        NSInteger page = [_swipeView currentPage];
        DDLogVerbose(@"page before close: %ld", (long)page);
        
        [[[ChatManager sharedInstance] getChatController: _username] destroyDataSourceForFriendname: name];
        [[[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:name] setChatActive:NO];
        @synchronized (_chats) {
            [_chats removeObjectForKey:name];
        }
        [_swipeView reloadData];
        page = [_swipeView currentPage];
        
        if (page >= _swipeView.numberOfPages) {
            page = _swipeView.numberOfPages - 1;
        }
        [_swipeView scrollToPage:page duration:0.2];
        
        DDLogVerbose(@"page after close: %ld", (long)page);
        NSString * name = [self nameForPage:page];
        DDLogVerbose(@"name after close: %@", name);
        [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] setCurrentChat:name];
        [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] postRefresh];
        
    }
}

-(void) closeTab {
    [self closeTabName: [self getCurrentTabName]];
}

-(void) closeAllTabs {
    NSInteger count = [_swipeView numberOfPages]-1;
    for (NSInteger page = count; page > 0; page--) {
        NSString * name = [self nameForPage:page];
        
        [[[ChatManager sharedInstance] getChatController: _username] destroyDataSourceForFriendname: name];
        [[[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:name] setChatActive:NO];
        @synchronized (_chats) {
            [_chats removeObjectForKey:name];
        }
    }
    
    [_swipeView reloadData];
    [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] setCurrentChat:nil];
    [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] postRefresh];
}

-(void) logout {
    DDLogVerbose(@"logout");
    
    //remove gestures
    for (id gesture in _sideMenuGestures) {
        [self.view removeGestureRecognizer:gesture];
        [self.navigationController.view removeGestureRecognizer:gesture];
        [self.swipeView.scrollView removeGestureRecognizer:gesture];
    }
    
    [_sideMenuGestures removeAllObjects];
    _sideMenuGestures = nil;
    
    //blow the views away
    _friendView = nil;
    
    [[[NetworkManager sharedInstance] getNetworkController:_username] logout];
    [[[ChatManager sharedInstance] getChatController: _username] logout];
    [[IdentityController sharedInstance] logout];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_swipeView removeFromSuperview];
    _swipeView = nil;
    
    //could be logging out as a result of deleting the logged in identity, which could be the only identity
    //if this is the case we want to go to the signup screen not the login screen
    //make it like a pop by inserting view controller into stack and popping
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle: nil];
    UIViewController * viewController;
    
    if ([[[IdentityController sharedInstance] getIdentityNames ] count] == 0 ) {
        viewController = [storyboard instantiateViewControllerWithIdentifier:@"signupViewController"];
    }
    else {
        viewController = [storyboard instantiateViewControllerWithIdentifier:@"loginViewController"];
    }
    
    NSArray *vcs =  @[viewController, self];
    [self.navigationController setViewControllers:vcs animated:NO];
    [self.navigationController popViewControllerAnimated:YES];
}

-(void) ensureVoiceDelegate {
    
    if (!_voiceDelegate) {
        _voiceDelegate = [[VoiceDelegate alloc] initWithUsername:_username ourVersion:[[IdentityController sharedInstance] getOurLatestVersion: _username]];
        _voiceDelegate.delegate = self;
    }
}


- (IBAction)buttonTouchUpInside:(id)sender {
    DDLogVerbose(@"touch up inside");
    [_buttonTimer invalidate];
    
    NSTimeInterval interval = -[_buttonDownDate timeIntervalSinceNow];
    // Friend * afriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:[self getCurrentTabName]];
    
    if (interval < voiceRecordDelay) {
        
        if (![self handleTextActionResign:NO]) {
            [self resignAllResponders];
            [self scrollHome];
        }
    }
    else {
        if ([_voiceDelegate isRecording]) {
            [_voiceDelegate stopRecordingSend:[NSNumber numberWithBool:YES]];
        }
    }
}



- (IBAction)buttonTouchDown:(id)sender {
    _buttonDownDate = [NSDate date];
    DDLogVerbose(@"touch down at %@", _buttonDownDate);
    
    //kick off timer
    [_buttonTimer invalidate];
    _buttonTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(buttonTimerFire:) userInfo:[self getCurrentTabName] repeats:NO];
    
}

- (IBAction)buttonTouchUpOutside:(id)sender {
    DDLogVerbose(@"touch up outside");
    
    [_buttonTimer invalidate];
    NSTimeInterval interval = -[_buttonDownDate timeIntervalSinceNow];
    
    
    
    if ([_voiceDelegate isRecording]) {
        
        if (interval > voiceRecordDelay) {
            [_voiceDelegate stopRecordingSend: [NSNumber numberWithBool:NO]];
            [UIUtils showToastKey:@"recording_cancelled"];
            [self updateTabChangeUI];
            return;
        }
        
    }
}

-(void) buttonTimerFire:(NSTimer *) timer {
    
    Friend * afriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:[self getCurrentTabName]];
    
    if (afriend) {
        if (afriend.isDeleted) {
            [self closeTab];
        }
        else {
            if (![self handleTextActionResign:NO]) {
                BOOL disableVoice = [UIUtils getBoolPrefWithDefaultNoForUser:_username key:@"_user_pref_disable_voice"];
                if (!disableVoice) {
                    
                    [self ensureVoiceDelegate];
                    [_voiceDelegate startRecordingUsername: afriend.name];
                }
                else {
                    [self closeTab];
                }
            }
        }
    }
}

- (void) backPressed {
    [self scrollHome];
    if (_swipeView.currentPage == 0) {
        [self presentViewController:[[SideMenuManager defaultManager] menuLeftNavigationController] animated:YES completion:nil];
    }
}

-(void) scrollHome {
    if (_swipeView.currentPage != 0) {
        _scrollingTo = 0;
        [_swipeView scrollToPage:0 duration:0.5];
    }
}

- (void) startProgress: (NSNotification *) notification {
    DDLogInfo(@"startProgress");
    NSDictionary * userInfo = [notification userInfo];
    [_progress setObject: @""  forKey:[userInfo objectForKey:@"key"]];
    [UIUtils startSpinAnimation: _backImageView];
    DDLogInfo(@"progress count:%ld", (unsigned long)[_progress count]);
}

-(void) stopProgress: (NSNotification *) notification {
    DDLogInfo(@"stopProgress");
    NSDictionary * userInfo = [notification userInfo];
    [_progress removeObjectForKey:[userInfo objectForKey:@"key"]];
    
    if ([_progress count] == 0) {
        [UIUtils stopSpinAnimation:_backImageView];
    }
    DDLogInfo(@"progress count:%ld", (long)[_progress count]);
}




-(void) unauthorized: (NSNotification *) notification {
    NSString * username = [[notification userInfo] objectForKey:@"username"];
    DDLogVerbose(@"unauthorized, username: %@", username);
    if ([username isEqualToString:_username]) {
        DDLogDebug(@"logging out SwipeViewController");
        [self logout];
    }
}

-(void) newMessage: (NSNotification *) notification {
    SurespotMessage * message = notification.object;
    NSString * currentChat =[self getCurrentTabName];
    //pulse if we're logged in as the user
    if (currentChat &&
        ![message.from isEqualToString: currentChat] &&
        [[[IdentityController sharedInstance] getIdentityNames] containsObject:message.to]) {
        
        [UIUtils startPulseAnimation:_backImageView];
    }
}

-(void) invite: (NSNotification *) notification {
    //  Friend * thefriend = notification.object;
    NSString * currentChat = [self getCurrentTabName];
    //Don't show the toast anymore as we display notification
    //show toast if we're not on the tab or home page, and pulse if we're logged in as the user
    if (currentChat) {
        //[UIUtils showToastMessage:[NSString stringWithFormat:NSLocalizedString(@"notification_invite", nil), _username, thefriend.nameOrAlias] duration:1];
        
        [UIUtils startPulseAnimation:_backImageView];
    }
}


-(void) inviteAccepted: (NSNotification *) notification {
    //NSString * acceptedBy = notification.object;
    NSString * currentChat = [self getCurrentTabName];
    // pulse if we're logged in as the user
    if (currentChat) {
        [UIUtils startPulseAnimation:_backImageView];
    }
}


#pragma mark -
#pragma mark IASKAppSettingsViewControllerDelegate ish protocol
-(void) settingsChanged: (NSNotification *) notification {
    NSDictionary * userInfo = [notification userInfo];
    if ([userInfo objectForKey:@"pref_black_theme"]) {
        _appSettingsViewController = [SurespotSettingsViewController new];
        _appSettingsViewController.settingsStore = [[SurespotSettingsStore alloc] initWithUsername:_username];
        _appSettingsViewController.delegate = self;
        
        [self.navigationController popViewControllerAnimated:YES];
        [self.navigationController popToViewController: self animated:FALSE];
        [self.navigationController pushViewController:_appSettingsViewController animated:FALSE];
        [self setThemeStuff];
    }
    
    [self updateTabChangeUI];
}


- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    //[self dismissModalViewControllerAnimated:YES];
    
    // your code here to reconfigure the app for changed settings
    [self setBackgroundImageController:sender];
    [self setThemeStuff];
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
    DDLogVerbose(@"setting tapped %@", specifier.key);
    
    if ([specifier.key isEqualToString:@"_user_assign_background_image_key"]) {
        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
        NSString * key = [NSString stringWithFormat:@"%@%@", _username, @"_background_image_url"];
        NSURL * bgImageUrl = [defaults URLForKey:key];
        
        if (bgImageUrl) {
            NSString * assignString = NSLocalizedString(@"pref_title_background_image_select", nil);
            //set preference string
            [defaults setObject:assignString forKey:[ _username stringByAppendingString:specifier.key]];
            //remove image url from defaults
            [defaults removeObjectForKey:key];
            //delete image file from disk
            [[NSFileManager defaultManager] removeItemAtURL:bgImageUrl error:nil];
            [sender.tableView reloadData];
            [self setBackgroundImageController:nil];
        }
        else {
            //select and assign image
            _imageDelegate = [[ImageDelegate alloc]
                              initWithUsername:_username
                              ourVersion:[[IdentityController sharedInstance] getOurLatestVersion: _username]
                              theirUsername:_username];
            [ImageDelegate startBackgroundImageSelectControllerFromViewController:sender usingDelegate:_imageDelegate];
        }
        return;
    }
}

-(void) showSettings {
    self.appSettingsViewController.showDoneButton = NO;
    [self.navigationController pushViewController:self.appSettingsViewController animated:YES];
}


- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return 1;
}

- (SurespotPhoto *)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index == 0 && _imageMessage)
        return [[SurespotPhoto alloc] initWithURL:[NSURL URLWithString:_imageMessage.data]
                                 encryptionParams:[[EncryptionParams alloc]
                                                   initWithOurUsername:_username
                                                   ourVersion:[_imageMessage getOurVersion: _username]
                                                   theirUsername: [_imageMessage getOtherUser: _username]
                                                   theirVersion:[_imageMessage getTheirVersion: _username]
                                                   iv:_imageMessage.iv
                                                   hashed: [_imageMessage hashed]]];
    return nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    //if we're showing TOS don't let them dismiss
    if ([popoverController.contentViewController class] == [HelpViewController class]) {
        BOOL tosClicked = [[NSUserDefaults standardUserDefaults] boolForKey:@"hasClickedTOS"];
        return tosClicked;
    }
    else {
        return YES;
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.popover = nil;
}



-(void) resignAllResponders {
    DDLogVerbose(@"resignAllResponders");
    [_messageTextView resignFirstResponder];
    [_inviteTextView resignFirstResponder];
    [_giphySearchTextView resignFirstResponder];
}




-(void) backgroundImageChanged: (NSNotification *) notification {
    IASKAppSettingsViewController * controller = notification.object;
    [self setBackgroundImageController: controller];
}

-(void) setBackgroundImageController: (IASKAppSettingsViewController *) controller {
    NSUserDefaults  * defaults = [NSUserDefaults standardUserDefaults];
    NSString * username = _username;
    NSURL * url = [defaults URLForKey:[NSString stringWithFormat:@"%@%@",username, @"_background_image_url"]];
    if (url) {
        _hasBackgroundImage = YES;
        _bgImageView.contentMode = UIViewContentModeScaleAspectFill;
        [_bgImageView setImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:url]]];
        [_bgImageView setAlpha: 0.5f];
    }
    else {
        _hasBackgroundImage = NO;
        _bgImageView.image = nil;
        [_bgImageView setAlpha: 1];
        [_bgImageView setBackgroundColor: [UIUtils isBlackTheme] ? [UIColor blackColor] : [UIColor whiteColor]];
        
    }
    
    //reload the settings table view
    [controller.tableView reloadData];
    
    //reload the table view cells
    @synchronized (_chats) {
        for (NSString * key in [_chats allKeys]) {
            id tableView = [_chats objectForKey:key];
            if ([tableView respondsToSelector:@selector(reloadData)]) {
                [tableView reloadData];
            }
        }
    }
    
    [_friendView reloadData];
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setBackgroundImageController: nil];
    [self updateTabChangeUI];
    [self setBackButtonIcon];
    [self setThemeStuff];
    [self showHeader];
}


- (void)attributedLabel:(__unused TTTAttributedLabel *)label
   didSelectLinkWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}


- (void)attributedLabel:(TTTAttributedLabel *)label
didSelectLinkWithPhoneNumber:(NSString *)phoneNumber {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: [NSString stringWithFormat:@"tel://%@", phoneNumber]]];
}

-(void) setTextBoxHints {
    NSInteger tbHintCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"tbHintCount"];
    if (tbHintCount++ < 6) {
        [_inviteTextView setPlaceholder:NSLocalizedString(@"invite_hint", nil)];
        [_messageTextView setPlaceholder:NSLocalizedString(@"message_hint", nil)];
    }
    [[NSUserDefaults standardUserDefaults] setInteger:tbHintCount forKey:@"tbHintCount"];
    [_giphySearchTextView setPlaceholder:NSLocalizedString(@"search", nil)];
}


-(void) handleNotification {
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    DDLogDebug(@"handleNotification, defaults: %@", defaults);
    //if we entered app via notification defaults will be set
    NSString * notificationType = [defaults objectForKey:@"notificationType"];
    NSString * to = [defaults objectForKey:@"notificationTo"];
    if ([notificationType isEqualToString:@"message"]) {
        NSString * from = [defaults objectForKey:@"notificationFrom"];
        if (from && [to isEqualToString:_username]) {
            [self showChat:from scroll: NO];
        }
    }
    else {
        if ([notificationType isEqualToString:@"invite"]) {
            if ([to isEqualToString:_username]) {
                [self scrollHome];
            }
        }
    }
    
    [defaults removeObjectForKey:@"notificationType"];
    [defaults removeObjectForKey:@"notificationTo"];
    [defaults removeObjectForKey:@"notificationFrom"];
}

-(NSString *) checkDefaultsForChat {
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSString * notificationType = [defaults objectForKey:@"notificationType"];
    NSString * to = [defaults objectForKey:@"notificationTo"];
    if ([notificationType isEqualToString:@"message"]) {
        NSString * from = [defaults objectForKey:@"notificationFrom"];
        if (from && [to isEqualToString:_username]) {
            return from;
        }
    }
    return nil;
}

-(void) userSwitch {
    DDLogDebug(@"userSwitch");
    
    @synchronized (_chats) {
        [_chats removeAllObjects];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_swipeView removeFromSuperview];
    [self disableMessageModeShowKeyboard:NO setResponders:YES];
    _swipeView = nil;
    
    //remove gestures
    for (id gesture in _sideMenuGestures) {
        [self.view removeGestureRecognizer:gesture];
        [self.navigationController.view removeGestureRecognizer:gesture];
        [self.swipeView.scrollView removeGestureRecognizer:gesture];
    }
    
    [_sideMenuGestures removeAllObjects];
    _sideMenuGestures = nil;
}

-(void) reloadSwipeViewData {
    [_swipeView reloadData];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    
    [self disableMessageModeShowKeyboard:NO setResponders:YES];
    
    
}

- (NSString *) getCurrentTabName
{
    if ([_swipeView currentItemIndex] == 0) {
        return nil;
    }
    
    if ([_chats count] == 0) {
        return nil;
    }
    
    
    UsernameAliasMap * aliasMap;
    @synchronized (_chats) {
        NSArray *keys = [self sortedAliasedChats];
        NSInteger index = [_swipeView currentItemIndex];
        if (index > [keys count]) {
            index = [keys count];
        }
        
        index -= 1;
        
        aliasMap = [keys objectAtIndex: index];
    }
    
    return [aliasMap username];
}

-(void) setBackButtonIcon {
    
    if (!_backImageView) {
        //iOS 11 fucks insets: http://www.matrixprojects.net/p/uibarbuttonitem-ios11/
        SurespotLeftNavButton *backButton;
        if (@available(iOS 11, *)) {
            backButton = [[SurespotLeftNavButton alloc] initWithDimen: 36.0f inset:26];
        }
        else {
            backButton = [[SurespotLeftNavButton alloc] initWithDimen: 36.0f inset:10];
        }
        [backButton addTarget:self action:@selector(backPressed) forControlEvents:UIControlEventTouchUpInside];
        _backButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
        
        UIImage * backImage = [UIImage imageNamed:@"surespot_logo"];
        [backButton setBackgroundImage:backImage  forState:UIControlStateNormal];
        [backButton setContentMode:UIViewContentModeScaleAspectFit];
        _backImageView = backButton;
        
        self.navigationItem.leftItemsSupplementBackButton = NO;
        self.navigationItem.hidesBackButton = YES;
        
    }
    
    if (_swipeView.currentPage == 0) {
        
        if (!_homeBackButtons) {
            //hamburgler
            UIImage * hamburgerImage = [UIImage imageNamed:@"drawer"];
            SurespotLeftNavButton * hamButton = [[SurespotLeftNavButton alloc] initWithDimen: 16.0f inset:16];
            [hamButton setBackgroundImage:hamburgerImage forState:UIControlStateNormal];
            [hamButton setContentMode:UIViewContentModeCenter];
            UIBarButtonItem * hamItem = [[UIBarButtonItem alloc] initWithCustomView:hamButton];
            _homeBackButtons = @[hamItem, _backButtonItem];
        }
        
        self.navigationItem.leftBarButtonItems = _homeBackButtons;
    }
    else {
        if (!_chatBackButtons) {
            //hamburgler
            UIImage * backImage = [UIImage imageNamed:@"back"];
            SurespotLeftNavButton * backButton = [[SurespotLeftNavButton alloc] initWithDimen: 16.0f inset:16];
            [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
            [backButton setContentMode:UIViewContentModeCenter];
            UIBarButtonItem * backItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
            _chatBackButtons = @[backItem, _backButtonItem];
        }
        self.navigationItem.leftBarButtonItems = _chatBackButtons;
    }
}

-(void) setBackButtonEnabled: (BOOL) enabled {
    [_backButtonItem setEnabled:enabled];
}

-(void) setThemeStuff {
    [_messageTextView setTextColor:[self getThemeForegroundColor]];
    [_messageTextView setPlaceholderColor:[self getThemeForegroundColor]];
    [_inviteTextView setTextColor:[self getThemeForegroundColor]];
    [_inviteTextView setPlaceholderColor:[self getThemeForegroundColor]];
    [_giphySearchTextView setTextColor:[self getThemeForegroundColor]];
    [_giphySearchTextView setPlaceholderColor:[self getThemeForegroundColor]];
    
    if ([UIUtils isBlackTheme]) {
        [_giphyImage setImage:[UIImage imageNamed:@"powered_by_giphy_dark"]];
    }
    else {
        [_giphyImage setImage:[UIImage imageNamed:@"powered_by_giphy_light"]];
    }
}

- (IBAction)expandTouchUpInside:(id)sender {
    _currentMode = MessageModeNone;
    [self updateTabChangeUI];
}


- (IBAction)gifTouchUpInside:(id)sender {
    [self setMessageMode:MessageModeGIF];
}

-(void) giphyImageViewTapped: (UITapGestureRecognizer*) recognizer {
    [self searchGifs];
}


- (IBAction)galleryTouchUpInside:(id)sender {
    [self setMessageMode:MessageModeGallery];
    
}
- (IBAction)cameraTouchUpInside:(id)sender {
    [self setMessageMode:MessageModeCamera];
}
- (IBAction)qrTouch:(id)sender {
    QRInviteViewController * controller = [[QRInviteViewController alloc] initWithNibName:@"QRInviteView" username: _username];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:controller];
        _popover.delegate = self;
        CGFloat x = self.view.bounds.size.width;
        CGFloat y =self.view.bounds.size.height;
        DDLogVerbose(@"setting popover x, y to: %f, %f", x/2,y/2);
        [_popover setPopoverContentSize:CGSizeMake(320, 370) animated:NO];
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
        
    } else {
        [self resignAllResponders];
        [self.navigationController pushViewController:controller animated:YES];
    }
}



// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWillBeShown:(NSNotification*)aNotification {
    if (_suspendKeyboardListeners) return;
    DDLogInfo(@"keyboard shown, mode: %ld", _currentMode);
    NSDictionary* info = [aNotification userInfo];
    NSTimeInterval animationDuration;
    UIViewAnimationOptions curve;
    [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&curve];
    CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    DDLogInfo(@"keyboardHeight: %f", keyboardRect.size.height);
    
    CGFloat keyboardHeight = keyboardRect.size.height;
    
    
    CGFloat deltaHeight = keyboardHeight - _messageBarState.keyboardHeight;
    _messageBarState.keyboardHeight = keyboardHeight;
    
    DDLogInfo(@"deltaHeight: %f", deltaHeight);
    if (deltaHeight == 0) return;
    NSInteger offsets = 0;
    
    //if we're opening gif view, move the views to the top of it
    if (_currentMode == MessageModeGIF && _gifOffsets == 0) {
        _gifOffsets = 100;
        offsets = 100;
    }
    
    DDLogDebug(@"keyboardState galleryViewHeight: %f", _messageBarState.galleryViewHeight);
    //if the gallery view is showing
    if (_messageBarState.galleryViewHeight > 0) {
        
        //if the gallery view is showing and the keyboard is coming in we now need to adjust to the keyboard location
        //so use the delta of the keyboard height and the gallery view height
        deltaHeight = _messageBarState.keyboardHeight - _messageBarState.galleryViewHeight;
        DDLogInfo(@"gallery deltaHeight: %f", deltaHeight);
        
        _messageBarState.galleryViewHeight = 0;
    }
    
    [UIView animateWithDuration:animationDuration delay:0.0 options:curve animations:^{
        NSInteger offsetDelta = -(deltaHeight+offsets);
        [self moveViewsVerticallyBy:-deltaHeight];
        if (offsetDelta != 0) {
            [self setContentOffsets:offsetDelta];
        }
        if (_currentMode == MessageModeGIF && deltaHeight != 0) {
            [self animateGifWindowOpenSetContent: NO];
        }
        [self hideGalleryFrame:_galleryHeight];
    } completion:^(BOOL completion) {
        
    }];
}


// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification *) aNotification
{
    if (_suspendKeyboardListeners) return;
    DDLogInfo(@"keyboard hide, mode: %ld", (long)_currentMode);
    NSDictionary* info = [aNotification userInfo];
    NSTimeInterval animationDuration;
    UIViewAnimationOptions curve;
    [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&curve];
    CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardRect.size.height;
    
    //height is reported as 0 sometimes WTF apple
    DDLogInfo(@"keyboard reported height: %f, my height: %f", keyboardHeight, _messageBarState.keyboardHeight);
    keyboardHeight = _messageBarState.keyboardHeight;
    
    NSInteger offsets = 0;
    if (_gifOffsets > 0) {
        offsets = _gifOffsets;
        _gifOffsets = 0;
    }
    [self animateMoveViewsVerticallyBy:keyboardHeight duration:animationDuration curve:curve offsetDelta: keyboardHeight + offsets];
    [self disableMessageModeShowKeyboard: NO setResponders:NO];
    
    _messageBarState.keyboardHeight = 0.0f;
}

#pragma mark - Gesture recognizer delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

-(void) messageTextViewTapped: (UITapGestureRecognizer*) recognizer {
    DDLogInfo(@"messageTextViewTapped");
    _currentMode = MessageModeKeyboard;
    
    //if the gallery view and keyboard are open, hide the gallery view
    //if the keyboard's not open it'll hide the gallery view when it's shown
    if (_messageBarState.galleryViewHeight > 0 && _messageBarState.keyboardHeight > 0) {
        _messageBarState.galleryViewHeight = 0;
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options: UIViewAnimationCurveEaseOut
                         animations:^{
                             NSInteger yDelta = _galleryHeight;
                             [self hideGalleryFrame: yDelta];
                             [self updateTabChangeUI];
                         }
                         completion:^(BOOL finished){
                             DDLogDebug(@"disable mode animation finished");
                             [_galleryView removeFromSuperview];
                             _galleryView = nil;
                             
                         }];
    }
    else {
        [self updateTabChangeUI];
    }
}

-(void) animateMoveViewsVerticallyBy: (NSInteger) yDelta duration: (NSTimeInterval) animationDuration curve: (UIViewAnimationOptions) curve offsetDelta: (NSInteger) offsetDelta
{
    // run animation using keyboard's curve and duration
    [UIView animateWithDuration:animationDuration delay:0.0 options:curve animations:^{
        
        [self moveViewsVerticallyBy:yDelta];
        if (offsetDelta != 0) {
            [self setContentOffsets:offsetDelta];
        }
    } completion:^(BOOL completion) {
        
    }];
}


-(void) moveViewsVerticallyBy:(NSInteger) yDelta {
    
    DDLogDebug(@"moveViewsVerticallyBy, yDelta: %ld", yDelta);
    
   // DDLogDebug(@"moveViewsVerticallyBy, text frame origin before: %f, height: %f", _textFieldContainer.frame.origin.y, _textFieldContainer.frame.size.height);
    DDLogDebug(@"moveViewsVerticallyBy, swipe view frame origin before: %f, frame height: %f, bounds height: %f", _swipeView.frame.origin.y, _swipeView.frame.size.height, _swipeView.bounds.size.height);
    CGRect textFieldFrame = _textFieldContainer.frame;
    textFieldFrame.origin.y += yDelta;
    _textFieldContainer.frame = textFieldFrame;

    CGRect frame = _swipeView.frame;
    frame.size.height += yDelta;
    _swipeView.frame = frame;
  //  DDLogDebug(@"moveViewsVerticallyBy, text frame origin after: %f, height: %f", _textFieldContainer.frame.origin.y, _textFieldContainer.frame.size.height);
    DDLogDebug(@"moveViewsVerticallyBy, swipe view frame origin after: %f, height: %f, bounds height: %f", _swipeView.frame.origin.y, _swipeView.frame.size.height, _swipeView.bounds.size.height);
}

-(void) setContentOffsets: (NSInteger) yDelta  {
    
    DDLogDebug(@"setContentOffsets: %ld",yDelta);
    // size or move views appropriately so they are not obscured by the keyboard
    @synchronized (_chats) {
        for (NSString * key in [_chats allKeys]) {
            UITableView * tableView = [_chats objectForKey:key];
            
            //            UITableViewCell * bottomCell = nil;
            //            NSArray * visibleCells = [tableView visibleCells];
            //            if ([visibleCells count ] > 0) {
            //                bottomCell = [visibleCells objectAtIndex:[visibleCells count]-1];
            //            }
            //
            //            if (bottomCell) {
            //    CGRect aRect = self.view.frame;
            //    aRect.size.height -= deltaHeight;
            //   if (!CGRectContainsPoint(aRect, bottomCell.frame.origin) ) {
            if ([tableView respondsToSelector:@selector(contentOffset)]) {
                CGPoint newOffset = CGPointMake(0, tableView.contentOffset.y - yDelta);
                [tableView setContentOffset:newOffset animated:NO];
            }
            //  }
            //            }
        }
    }
    
}

-(void) setMessageMode: (MessageMode) mode {
    BOOL keyboardOpen = _messageBarState.keyboardHeight > 0;
    
    if (mode == _currentMode) {
        DDLogInfo(@"setMessageMode same mode disabling.");
        [self disableMessageModeShowKeyboard:keyboardOpen setResponders:YES];
        return;
    }
    
    _currentMode = mode;
    DDLogInfo(@"setMessageMode, mode: %ld, keyboard open: %d, keyboard height: %f", (long)mode, keyboardOpen,  _messageBarState.keyboardHeight);
    switch (mode) {
            
        case MessageModeGIF:
        {
            [_gifView removeFromSuperview];
            GiphyView * view = [[[NSBundle mainBundle] loadNibNamed:@"GiphyView" owner:self options:nil] firstObject];
            
            _gifView = view;
            if ([UIUtils isBlackTheme]) {
                [_gifView setBackgroundColor:[UIColor blackColor]];
            }
            CGRect gifFrame = _gifView.frame;
            gifFrame.origin.y =   _textFieldContainer.frame.origin.y;
            gifFrame.size.width = [UIScreen mainScreen].bounds.size.width;
            DDLogDebug(@"text field container frame origin y: %f",_textFieldContainer.frame.origin.y);
            gifFrame.size.height = 100;
            _gifView.frame = gifFrame;
            
            [self.view insertSubview:_gifView belowSubview:_textFieldContainer];
            
            DDLogDebug(@"created gif view frame origin y: %f, height: %f", _gifView.frame.origin.y, _gifView.frame.size.height);
            [view setCallback:^(id result) {
                [[[ChatManager sharedInstance] getChatController: _username ]  sendGifLinkUrl: result to: [self getCurrentTabName]];
            }];
            // open the keyboard, do rest in keyboard open handler
            [_giphySearchTextView becomeFirstResponder];
            if (keyboardOpen) {
                DDLogInfo(@"No mode currently set, or keyboard open so setting gif frame 0 height.");
                [self animateGifWindowOpenSetContent: YES];
            }
            
            [view loadRecentGifs: _username];
            break;
        }
        case MessageModeGallery:
        {
            [_galleryView removeFromSuperview];
            GalleryView * view = [[[NSBundle mainBundle] loadNibNamed:@"GalleryView" owner:self options:nil] firstObject];
            [view setBackgroundColor:[UIUtils isBlackTheme] ? [UIColor blackColor] : [UIColor whiteColor]];
            _galleryView = view;
            
            CGRect frame = [[UIScreen mainScreen] bounds];
            frame.origin.y = [[UIScreen mainScreen] bounds].size.height;
            frame.size.height = _galleryHeight;
            _galleryView.frame = frame;
            DDLogDebug(@"setting gallery view frame to y: %f, height: %f", _galleryView.frame.origin.y, _galleryView.frame.size.height);
            DDLogInfo(@"showGalleryView, keyboard height: %f",_messageBarState.keyboardHeight);
            
            //get the topmost window which should be the keyboard window
            UIWindow * theWindowWeWillUse = [UIUtils getHighestLevelWindowKeyboardShowing: (_messageBarState.keyboardHeight > 0)];
            NSString * friendname = [self getCurrentTabName];
            
            [view setCallback:^(id result) {
                BOOL confirm = [UIUtils getBoolPrefWithDefaultYesForUser:_username key:@"_user_pref_confirm_image_send"];
                if (confirm) {
                    
                    Friend * afriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName: friendname];
                    NSString * okString = NSLocalizedString(@"ok", nil);
                    
                    _alertController = [UIAlertController
                                        alertControllerWithTitle:NSLocalizedString(@"send", nil)
                                        message:[NSString stringWithFormat: NSLocalizedString(@"confirm_image_send", nil), [afriend nameOrAlias]]
                                        preferredStyle:UIAlertControllerStyleAlert];
                    
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                        DDLogVerbose(@"image send cancelled");
                    }];
                    [_alertController addAction:cancelAction];
                    
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:okString style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                        [[[ChatManager sharedInstance] getChatController: _username ]  sendImageMessage: result to: friendname];
                    }];
                    [_alertController addAction:okAction];
                    [UIUtils showAlertController:_alertController window: theWindowWeWillUse];
                }
                else {
                    [[[ChatManager sharedInstance] getChatController: _username ]  sendImageMessage: result to: friendname];
                }
            }];
            
            [view setMoreCallback:^(id result) {
                [self sendImageToFriendname:friendname viewController: self];
            }];
            
            __block NSInteger yDelta = _galleryHeight;
            [UIView animateWithDuration:0.5
                                  delay:0.0
                                options: UIViewAnimationCurveEaseIn
                             animations:^{
                                 [self hideGifView];
                                 
                                 //if keyboard open we know how much to move by
                                 if (keyboardOpen)
                                 {
                                     yDelta = _messageBarState.keyboardHeight;
                                 }
                                 
                                 //if not showing a view or the keyboard's not open
                                 if (!keyboardOpen) {
                                     [self moveViewsVerticallyBy: -yDelta];
                                     [self setContentOffsets:-yDelta];
                                 }
                                 CGRect frame = CGRectMake(0,  self.view.frame.origin.y + self.view.frame.size.height - yDelta, self.view.frame.size.width, yDelta);
                                 DDLogDebug(@"setting gallery view frame to y: %f, height: %f", frame.origin.y, frame.size.height);
                                 
                                 _galleryView.frame = frame;
                                 _messageBarState.galleryViewHeight = yDelta;
                             }
                             completion:^(BOOL finished){
                                 [_gifView removeFromSuperview];
                                 _gifView = nil;
                             }];
            
            [theWindowWeWillUse addSubview: _galleryView];
            [view fetchAssets];
            break;
        }
        case MessageModeCamera:
        {
            Friend * theFriend = [[[[ChatManager sharedInstance] getChatController: _username] getHomeDataSource] getFriendByName:[self getCurrentTabName]];
            if ([theFriend isFriend] && ![theFriend isDeleted]) {
                NSString * theirUsername = [self getCurrentTabName];
                _swipeView.suppressLayoutSubviews = YES;
                _imageDelegate = [[ImageDelegate alloc]
                                  initWithUsername:_username
                                  ourVersion:[[IdentityController sharedInstance] getOurLatestVersion: _username]
                                  theirUsername:theirUsername];
                _imageDelegate.delegate = self;
                //pull other views immediately coz they look janky
                [_gifView removeFromSuperview];
                [_galleryView removeFromSuperview];
                [self disableMessageModeShowKeyboard:NO setResponders:YES];
                [ImageDelegate startCameraControllerFromViewController:self usingDelegate:_imageDelegate];
            }
            break;
        }
    }
    [self updateTabChangeUI];
}

-(void) disableMessageModeShowKeyboard:(BOOL) showKeyboard setResponders: (BOOL) setResponders {
    DDLogDebug(@"disableMessageModeShowKeyboard: %d, setResponders: %d, keyboard height: %f",showKeyboard, setResponders, _messageBarState.keyboardHeight);
    NSInteger galleryViewHeight = _messageBarState.galleryViewHeight;
    _messageBarState.galleryViewHeight = 0;
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options: UIViewAnimationCurveEaseOut
                     animations:^{
                         if (setResponders) {
                             NSInteger yDelta = _galleryHeight;
                             
                             [self hideGifView];
                             
                             if (galleryViewHeight > 0) {
                                 //
                                 //if the keyboard's not showing and we're hiding the message mode view, scroll the ui down
                                 if ([_messageBarState keyboardHeight] == 0 && !showKeyboard) {
                                     [self moveViewsVerticallyBy:yDelta];
                                     [self setContentOffsets:yDelta];
                                 }
                                 [self hideGalleryFrame: yDelta];
                             }
                         }
                     }
                     completion:^(BOOL finished){
                         DDLogDebug(@"disable mode animation finished");
                         [_gifView removeFromSuperview];
                         [_galleryView removeFromSuperview];
                         _gifView = nil;
                         _galleryView = nil;
                     }];
    
    if (showKeyboard) {
        if (setResponders) {
            [_messageTextView becomeFirstResponder];
        }
        //        _currentMode = MessageModeKeyboard;
    }
    else {
        if (setResponders) {
            [self resignAllResponders];
        }
    }
    _currentMode = MessageModeNone;
    [_alertController dismissViewControllerAnimated:YES completion:nil];
    [self updateTabChangeUI];
}

-(void) hideGalleryFrame: (NSInteger) yDelta {
    CGRect frame = CGRectMake(0,  self.view.frame.origin.y + self.view.frame.size.height, self.view.frame.size.width, yDelta);
    DDLogDebug(@"hideGalleryFrame setting frame to y: %f, height: %f", frame.origin.y, frame.size.height);
    _galleryView.frame = frame;
}

-(void) animateGifWindowOpenSetContent: (BOOL) setContent {
    DDLogDebug(@"animateGifWindowOpen,setContent: %d", setContent);
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options: UIViewAnimationCurveEaseIn
                     animations:^{
                         CGRect gifFrame = _gifView.frame;
                         _gifOffsets = 100;
                         gifFrame.origin.y =   _textFieldContainer.frame.origin.y - _gifOffsets;
                         DDLogDebug(@"text field container frame origin y: %f",_textFieldContainer.frame.origin.y);
                         _gifView.frame = gifFrame;
                         DDLogDebug(@"setting frame to y: %f, height: %f", _gifView.frame.origin.y, _gifView.frame.size.height);
                         
                         if (setContent) {
                             [self setContentOffsets:-_gifOffsets];
                         }
                         [self hideGalleryFrame:_galleryHeight];
                         _messageBarState.galleryViewHeight = 0;
                     } completion:^(BOOL finished) {
                         DDLogDebug(@"animateGifWindow open removing gallery view from superview");
                         [_galleryView removeFromSuperview];
                         _galleryView = nil;
                     }];
}

-(void) hideGifView {
    CGRect gifFrame = _gifView.frame;
    gifFrame.origin.y =   _textFieldContainer.frame.origin.y;
    DDLogDebug(@"hideGifView: text field container frame origin y: %f",_textFieldContainer.frame.origin.y);
    _gifView.frame = gifFrame;
    
    if (_gifOffsets != 0) {
        NSInteger offsets = _gifOffsets;
        _gifOffsets = 0;
        [self setContentOffsets:offsets];
    }
}

-(void) expand {
    if (self.collapsed) {
        self.collapsed = NO;
        
        DDLogDebug(@"expand");
        [UIView animateWithDuration:0.2
                              delay:0.0
                            options: UIViewAnimationCurveEaseIn
                         animations:^{
                             CGRect cameraFrame = _cameraButton.frame;
                             CGRect theButtonFrame = _theButton.frame;
                             CGRect messageTextFrame = _messageTextView.frame;
                             
                             CGFloat x = cameraFrame.origin.x + cameraFrame.size.width + 6;
                             CGFloat newWidth = theButtonFrame.origin.x - 4 - x;
                             
                             //move left of text frame to right of camera button
                             messageTextFrame.origin.x = x;
                             messageTextFrame.size.width = newWidth;
                             _messageTextView.frame = messageTextFrame;
                             DDLogDebug(@"Expand, _messageTextView frame: %@", _messageTextView);
                         } completion:^(BOOL finished) {
                             //show buttons afterwards
                             [self updateTabChangeUI];
                         }];
        
        
    }
    //    else {
    //        [self updateTabChangeUI];
    //    }
}

-(void) collapse {
    if (!self.collapsed) {
        self.collapsed = YES;
        DDLogDebug(@"collapse");
        [UIView animateWithDuration:0.2
                              delay:0.0
                            options: UIViewAnimationCurveEaseOut
                         animations:^{
                             CGRect expandFrame = _expandButton.frame;
                             CGRect messageTextFrame = _messageTextView.frame;
                             
                             _messageBarState.origTextMessageFrame = messageTextFrame;
                             
                             CGFloat originalX = messageTextFrame.origin.x;
                             
                             //move left of text frame to right of expand button
                             messageTextFrame.origin.x = expandFrame.origin.x + expandFrame.size.width;
                             CGFloat deltaX = originalX - messageTextFrame.origin.x;
                             messageTextFrame.size.width += deltaX;
                             _messageTextView.frame = messageTextFrame;
                             DDLogDebug(@"Collapse, _messageTextView frame: %@", _messageTextView);
                         } completion:^(BOOL finished) {
                             
                         }];
    }
}

-(BOOL) shouldExpand {
    return [self getCurrentTabName] && (_currentMode != MessageModeKeyboard);
}


-(void) voiceMessagePlayed: (SurespotMessage *) message {
    DDLogVerbose(@"voiceMessagePlayed: %@", message);
    //if we're on the same tab play next unplayed voice message
    NSString * currentTab = [self getCurrentTabName];
    if ([message.from isEqualToString: currentTab]) {
        NSInteger lastPlayedId = message.serverid;
        ChatDataSource * cds = [[[ChatManager sharedInstance] getChatController: _username] getDataSourceForFriendname: currentTab];
        
        
        //get visible cells
        UITableView * tableView = [self.chats objectForKey:currentTab];
        NSArray * visibleCells = tableView.visibleCells;
        MessageView * messageView = nil;
        //iterate through messages, get next received voice message and play it
        for (SurespotMessage * chatMessage in cds.messages) {
            if ([[chatMessage from] isEqualToString:currentTab] && [[chatMessage mimeType] isEqualToString: MIME_TYPE_M4A]) {
                if ([chatMessage serverid] > lastPlayedId && ![chatMessage voicePlayed]) {
                    //get visible cell for this message
                    for (id tableViewCell in visibleCells) {
                        if ([[tableViewCell message] isEqual:chatMessage]) {
                            messageView = tableViewCell;
                            break;
                        }
                    }
                    
                    [_voiceDelegate playVoiceMessage:chatMessage cell:messageView];
                    //       [_voiceDelegate attachCell: messageView];
                    break;
                }
            }
        }
    }
}


- (void)imageSelectionCompleted {
    DDLogDebug(@"imageSelectionCompleted");
    _swipeView.suppressLayoutSubviews = NO;
    [self showHeader];
}

@end
