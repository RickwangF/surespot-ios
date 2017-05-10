//
//  BackupIdentityViewController.m
//  surespot
//
//  Created by Adam on 11/28/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "BackupIdentityViewController.h"
#import "AfterBackupIdentityHelpViewController.h"
#import "IdentityController.h"
#import "CocoaLumberjack.h"
#import "SurespotConstants.h"
#import "UIUtils.h"
#import "LoadingView.h"
#import "GTLRDriveService.h"
#import "GTLRDrive.h"
#import <AppAuth/AppAuth.h>
#import "GTMAppAuth.h"
#import "FileController.h"
#import "NSData+Gunzip.h"
#import "NSString+Sensitivize.h"
#import "BackupHelpViewController.h"
#import "NSBundle+FallbackLanguage.h"
#import "SurespotConfiguration.h"
#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import "SurespotAppDelegate.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif


@interface BackupIdentityViewController ()
@property (strong, nonatomic) IBOutlet UILabel *labelGoogleDriveBackup;
@property (strong, nonatomic) IBOutlet UIButton *bSelect;
@property (strong, nonatomic) IBOutlet UILabel *accountLabel;
@property (atomic, strong) NSArray * identityNames;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;
@property (strong, nonatomic) IBOutlet UIButton *bExecute;

@property (nonatomic, nullable) GTMAppAuthFetcherAuthorization *authorization;
@property (nonatomic, strong) GTLRDriveService *driveService;
@property (atomic, strong) id progressView;
@property (atomic, strong) NSString * name;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (atomic, strong) NSString * url;
@property (strong, nonatomic) IBOutlet UIButton *bDocuments;
@property (nonatomic, strong) UIPopoverController * popover;
@property (strong, nonatomic) IBOutlet UILabel *lBackup;
@property (strong, nonatomic) IBOutlet UILabel *lDocuments;
@property (strong, nonatomic) IBOutlet UILabel *lSelect;

@end


static NSString *const kKeychainItemName = @"Google Drive surespot";
static NSString *const kNewKeychainItemName = @"Google surespot GTMAppAuth";
static NSString* const DRIVE_IDENTITY_FOLDER = @"surespot identity backups";
static NSString *const kRedirectURI = @"com.googleusercontent.apps.428168563991-kjkqs31gov2lmgh05ajbhcpi7bkpuop7:/oauthredirect";


@implementation BackupIdentityViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"backup", nil)];
    [_bExecute setTitle:NSLocalizedString(@"backup_drive", nil) forState:UIControlStateNormal];
    [self loadIdentityNames];
    self.navigationController.navigationBar.translucent = NO;
    
    self.driveService = [[GTLRDriveService alloc] init];
    _driveService.shouldFetchNextPages = YES;
    _driveService.retryEnabled = YES;
    
    [self setAccountFromKeychain];
    
    _labelGoogleDriveBackup.text = NSLocalizedString(@"google_drive", nil);
    
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"help",nil) style:UIBarButtonItemStylePlain target:self action:@selector(showHelp)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    [_userPicker selectRow:[_identityNames indexOfObject:(_selectUsername ? _selectUsername : [[IdentityController sharedInstance] getLoggedInUser])] inComponent:0 animated:YES];
    
    [_lDocuments setText:NSLocalizedString(@"documents", nil)];
    [_bDocuments setTitle:NSLocalizedString(@"backup_to_documents", nil) forState:UIControlStateNormal];
    [[_bDocuments titleLabel] setAdjustsFontSizeToFitWidth: YES];
    
    [_lSelect setText:NSLocalizedString(@"select_identity", nil)];
    [_lBackup setText:NSLocalizedString(@"help_backupIdentities1", nil)];
    
    _scrollView.contentSize = CGSizeMake(0, 765);
    
    //theme
    if ([UIUtils isBlackTheme]) {
        [self.view setBackgroundColor:[UIColor blackColor]];
        [self.scrollView setBackgroundColor:[UIColor blackColor]];
        [self.accountLabel setTextColor:[UIUtils surespotForegroundGrey]];
        [self.lSelect setTextColor:[UIUtils surespotForegroundGrey]];
        [self.lSelect setBackgroundColor:[UIUtils surespotGrey]];
        [self.lDocuments setTextColor:[UIUtils surespotForegroundGrey]];
        [self.lDocuments setBackgroundColor:[UIUtils surespotGrey]];
        [self.labelGoogleDriveBackup setTextColor:[UIUtils surespotForegroundGrey]];
        [self.labelGoogleDriveBackup setBackgroundColor:[UIUtils surespotGrey]];
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.popover = nil;
}

-(void) showHelp {
    BackupHelpViewController * controller = [[BackupHelpViewController alloc] initWithNibName:@"BackupHelpView" bundle:nil];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:controller];
        _popover.delegate = self;
        CGFloat x = self.view.bounds.size.width;
        CGFloat y =self.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        [_popover setPopoverContentSize:CGSizeMake(320, 480) animated:NO];
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
        
    } else {
        [self.navigationController pushViewController:controller animated:YES];
    }
}

-(void) showAfterBackupIdentityHelp {
    AfterBackupIdentityHelpViewController * controller = [[AfterBackupIdentityHelpViewController alloc] initWithNibName:@"AfterBackupIdentityHelpView" bundle:nil];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:controller];
        _popover.delegate = self;
        CGFloat x = self.view.bounds.size.width;
        CGFloat y = self.view.bounds.size.height;
        DDLogInfo(@"setting second popover x, y to: %f, %f", x/2,y/2);
        [_popover setPopoverContentSize:CGSizeMake(320, 480) animated:NO];
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
        
    } else {
        [self.navigationController pushViewController:controller animated:YES];
    }
}

-(void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView *__autoreleasing *)view {
    CGFloat x =self.view.bounds.size.width;
    CGFloat y =self.view.bounds.size.height;
    DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
    
    CGRect newRect = CGRectMake(x/2,y/2, 1,1 );
    *rect = newRect;
}


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
    if ([UIUtils isBlackTheme]) {
        [label setTextColor:[UIUtils surespotForegroundGrey]];
    }
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


-(void) setAccountFromKeychain {
    // Attempt to deserialize from Keychain in GTMAppAuth format.
    id<GTMFetcherAuthorizationProtocol> authorization =
    [GTMAppAuthFetcherAuthorization authorizationFromKeychainForName:kNewKeychainItemName];
    
    // If no data found in the new format, try to deserialize data from GTMOAuth2
    if (!authorization) {
        // Tries to load the data serialized by GTMOAuth2 using old keychain name.
        // If you created a new client id, be sure to use the *previous* client id and secret here.
        authorization =
        [GTMOAuth2KeychainCompatibility authForGoogleFromKeychainForName:kKeychainItemName
                                                                clientID:[[SurespotConfiguration sharedInstance] GOOGLE_CLIENT_ID]
                                                            clientSecret:[[SurespotConfiguration sharedInstance] GOOGLE_CLIENT_SECRET]];
        if (authorization) {
            // Remove previously stored GTMOAuth2-formatted data.
            [GTMOAuth2KeychainCompatibility removeAuthFromKeychainForName:kKeychainItemName];
            // Serialize to Keychain in GTMAppAuth format.
            [GTMAppAuthFetcherAuthorization saveAuthorization:(GTMAppAuthFetcherAuthorization *)authorization
                                            toKeychainForName:kNewKeychainItemName];
        }
    }
    
    self.driveService.authorizer = authorization;
    [self updateUI];
}

-(void) updateUI {
    if (_driveService.authorizer) {
        _accountLabel.text = [_driveService.authorizer userEmail];
        [_bSelect setTitle:NSLocalizedString(@"remove", nil) forState:UIControlStateNormal];
        [_bSelect.titleLabel setAdjustsFontSizeToFitWidth:YES];
        return;
    }
    
    _accountLabel.text = NSLocalizedString(@"no_google_account_selected", nil);
    [_bSelect setTitle:NSLocalizedString(@"select", nil) forState:UIControlStateNormal];
}

// Helper to check if user is authorized
- (BOOL)isAuthorized
{
    return [self.driveService.authorizer canAuthorize];
}

-(void) authorize {
    OIDServiceConfiguration *configuration =
    [GTMAppAuthFetcherAuthorization configurationForGoogle];
    NSURL * redirectURL = [NSURL URLWithString: kRedirectURI];
    // builds authentication request
    OIDAuthorizationRequest *request =
    [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                  clientId:[[SurespotConfiguration sharedInstance] GOOGLE_CLIENT_ID]
                                              clientSecret:[[SurespotConfiguration sharedInstance] GOOGLE_CLIENT_SECRET]
                                                    scopes:@[OIDScopeEmail, kGTLRAuthScopeDriveFile, kGTLRAuthScopeDriveMetadataReadonly]
                                               redirectURL:redirectURL
                                              responseType:OIDResponseTypeCode
                                      additionalParameters:nil];
    // performs authentication request
    SurespotAppDelegate *appDelegate = (SurespotAppDelegate *)[UIApplication sharedApplication].delegate;
    appDelegate.currentAuthorizationFlow =
    [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                   presentingViewController:self callback:^(OIDAuthState * _Nullable authState, NSError * _Nullable error) {
                                       if (authState) {
                                           // Creates the GTMAppAuthFetcherAuthorization from the OIDAuthState.
                                           GTMAppAuthFetcherAuthorization *authorization =
                                           [[GTMAppAuthFetcherAuthorization alloc] initWithAuthState:authState];
                                           
                                           self.driveService.authorizer = authorization;
                                           [GTMAppAuthFetcherAuthorization saveAuthorization:(GTMAppAuthFetcherAuthorization *)authorization
                                                                           toKeychainForName:kNewKeychainItemName];
                                           DDLogDebug(@"Got authorization tokens. Access token: %@",
                                                      authState.lastTokenResponse.accessToken);
                                           [self updateUI];
                                       } else {
                                           DDLogError(@"Authorization error: %@", [error localizedDescription]);
                                           
                                           [UIUtils showToastMessage:error.localizedDescription duration:2];
                                           
                                           self.driveService.authorizer = nil;
                                           _accountLabel.text = nil;
                                       }
                                       
                                   }];
}

- (IBAction)select:(id)sender {
    if ([self isAuthorized]) {
        [GTMAppAuthFetcherAuthorization removeAuthorizationFromKeychainForName:kNewKeychainItemName];
        _driveService.authorizer = nil;
        [self updateUI];
    }
    else {
        [self selectAccount];
    }
}

-(void) selectAccount {
    if (![self isAuthorized])
    {
        // Not yet authorized, request authorization and push the login UI onto the navigation stack.
        DDLogInfo(@"launching google authorization");
        [self authorize];
    }
}

-(void) ensureDriveIdentityDirectoryCompletionBlock: (CallbackBlock) completionBlock {
    
    GTLRDriveQuery_FilesList *queryFilesList = [GTLRDriveQuery_FilesList query];
    queryFilesList.q =  [NSString stringWithFormat:@"name='%@' and trashed = false and mimeType='application/vnd.google-apps.folder'", DRIVE_IDENTITY_FOLDER];
    
    [_driveService executeQuery:queryFilesList
              completionHandler:^(GTLRServiceTicket *ticket, GTLRDrive_FileList *result,
                                  NSError *error) {
                  if (error == nil) {
                      if (result.files.count > 0) {
                          NSString * identityDirId = nil;
                          
                          for (id file in result.files) {
                              identityDirId = [file identifier];
                              if (identityDirId) break;
                          }
                          completionBlock(identityDirId);
                          return;
                      }
                      else {
                          GTLRDrive_File *folderObj = [GTLRDrive_File object];
                          folderObj.name = DRIVE_IDENTITY_FOLDER;
                          folderObj.mimeType = @"application/vnd.google-apps.folder";
                          folderObj.parents = @[@"root"];
                          
                          GTLRDriveQuery_FilesCreate *query = [GTLRDriveQuery_FilesCreate queryWithObject:folderObj uploadParameters:nil];
                          [_driveService executeQuery:query
                                    completionHandler:^(GTLRServiceTicket *ticket, GTLRDrive_File *file,
                                                        NSError *error) {
                                        NSString * identityDirId = nil;
                                        if (error == nil) {
                                            
                                            if (file) {
                                                identityDirId = [file identifier];
                                            }
                                            
                                        } else {
                                            DDLogError(@"An error occurred: %@", error);
                                            
                                        }
                                        completionBlock(identityDirId);
                                        return;
                                        
                                    }];
                      }
                  } else {
                      DDLogError(@"An error occurred: %@", error);
                      completionBlock(nil);
                  }
              }];
}

- (IBAction)execute:(id)sender {
    if ([self isAuthorized]) {
        NSString * name = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
        _name = name;
        
        //show alert view to get password
        [UIUtils showPasswordAlertTitle:[NSString stringWithFormat:NSLocalizedString(@"backup_identity", nil), name]
                                message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name] controller:self callback:^(id password) {
                                    if (![UIUtils stringIsNilOrEmpty:password]) {
                                        [self backupIdentity:_name password:password];
                                    }
                                    
                                }];
    }
    
}

-(void) getIdentityFile: (NSString *) identityDirId name: (NSString *) name callback: (CallbackBlock) callback {
    GTLRDriveQuery_FilesList *queryFilesList = [GTLRDriveQuery_FilesList query];
    queryFilesList.q = [NSString stringWithFormat:@"name = '%@' and '%@' in parents and trashed = false", [[name  caseInsensitivize] stringByAppendingPathExtension: IDENTITY_EXTENSION], identityDirId];
    
    [_driveService executeQuery:queryFilesList
              completionHandler:^(GTLRServiceTicket *ticket, GTLRDrive_FileList *result,
                                  NSError *error) {
                  
                  if (error) {
                      DDLogError(@"An error occurred: %@", error);
                      callback(nil);
                      return;
                  }
                  
                  DDLogInfo(@"retrieved identity files");
                  NSInteger dlCount = result.files.count;
                  
                  if (dlCount == 1) {
                      callback(result.files[0]);
                      return;
                  }
                  else {
                      if (dlCount > 1) {
                          //delete all but one - shouldn't happen but just in case
                          for (long i=dlCount;i>1;i--) {
                              GTLRDriveQuery_FilesDelete *query = [GTLRDriveQuery_FilesDelete queryWithFileId: result.files[i-1].identifier];
                              [_driveService executeQuery:query
                                        completionHandler:^(GTLRServiceTicket *ticket, id object,
                                                            NSError *error) {
                                            if (error != nil) {
                                                DDLogError(@"An error occurred: %@", error);
                                            }
                                        }];
                          }
                          
                          callback(result.files[0]);
                          return;
                      }
                  }
                  
                  callback(nil);
              }];
}

-(void) backupIdentity: (NSString *) name password: (NSString *) password {
    _progressView = [LoadingView showViewKey:@"progress_backup_identity_drive"];
    
    [self ensureDriveIdentityDirectoryCompletionBlock:^(NSString * identityDirId) {
        if (!identityDirId) {
            [_progressView removeView];
            _progressView = nil;
            
            [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
            return;
        }
        
        DDLogInfo(@"got identity folder id %@", identityDirId);
        
        [[IdentityController sharedInstance] exportIdentityDataForUsername:name password:password callback:^(NSString *error, id identityData) {
            if (error) {
                [_progressView removeView];
                _progressView = nil;
                
                [UIUtils showToastMessage:error duration:2];
                return;
            }
            else {
                if (!identityData) {
                    [_progressView removeView];
                    _progressView = nil;
                    
                    [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
                    return;
                }
                
                [self getIdentityFile:identityDirId name:name callback:^(GTLRDrive_File * idFile) {
                    if (idFile) {
                        
                        GTLRDrive_File *driveFile = [GTLRDrive_File object] ;
                        GTLRUploadParameters *uploadParameters = [GTLRUploadParameters
                                                                  uploadParametersWithData:[identityData gzipDeflate]
                                                                  MIMEType:@"application/octet-stream"];
                        uploadParameters.shouldUploadWithSingleRequest = TRUE;
                        
                        GTLRDriveQuery_FilesUpdate *query = [GTLRDriveQuery_FilesUpdate queryWithObject:driveFile fileId:idFile.identifier uploadParameters:uploadParameters];
                        
                        [self.driveService executeQuery:query
                                      completionHandler:^(GTLRServiceTicket *ticket,
                                                          GTLRDrive_File *updatedFile,
                                                          NSError *error) {
                                          [_progressView removeView];
                                          _progressView = nil;
                                          
                                          if (error == nil) {
                                              [UIUtils showToastKey:@"identity_successfully_backed_up_to_google_drive" duration:2];
                                          } else {
                                              [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
                                          }
                                      }];
                        
                        
                    }
                    else {
                        GTLRDrive_File *driveFile = [GTLRDrive_File object] ;
                        driveFile.parents = @[identityDirId];
                        driveFile.mimeType = @"application/octet-stream";
                        NSString * caseInsensiveUsername = [name caseInsensitivize];
                        NSString * filename = [caseInsensiveUsername stringByAppendingPathExtension: IDENTITY_EXTENSION];
                        driveFile.originalFilename = filename;
                        driveFile.name = filename;
                        
                        GTLRUploadParameters *uploadParameters = [GTLRUploadParameters
                                                                  uploadParametersWithData:[identityData gzipDeflate]
                                                                  MIMEType:@"application/octet-stream"];
                        
                        GTLRDriveQuery_FilesCreate *query = [GTLRDriveQuery_FilesCreate  queryWithObject:driveFile
                                                                                        uploadParameters:uploadParameters];
                        
                        [self.driveService executeQuery:query
                                      completionHandler:^(GTLRServiceTicket *ticket,
                                                          GTLRDrive_File *updatedFile,
                                                          NSError *error) {
                                          [_progressView removeView];
                                          _progressView = nil;
                                          
                                          if (error == nil) {
                                              [UIUtils showToastKey:@"identity_successfully_backed_up_to_google_drive" duration:2];
                                          } else {
                                              [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
                                          }
                                      }];
                    }
                }];
            }
        }];
    }];
}

-(void) backupIdentityDocuments: (NSString *) name password: (NSString *) password {
    
    [[IdentityController sharedInstance] exportIdentityToDocumentsForUsername:name password:password callback:^(NSString *error, id identityData) {
        if (error) {
            
            [UIUtils showToastMessage:error duration:2];
            return;
        }
        else {
            
            [UIUtils showToastKey:@"backed_up_identity_to_documents" duration:2];
            [self showAfterBackupIdentityHelp];
            return;
        }
    }];
}


-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}


- (IBAction)executeLocal:(id)sender {
    //save exported identity file in documents folder
    
    NSString * name = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    _name = name;
    
    //show alert view to get password
    [UIUtils showPasswordAlertTitle:[NSString stringWithFormat:NSLocalizedString(@"backup_identity", nil), name]
                            message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name]
                         controller:self
                           callback:^(id password) {
                               if (![UIUtils stringIsNilOrEmpty:password]) {
                                   [self backupIdentityDocuments:_name password:password];
                               }
                           }];
    
    
}


@end
