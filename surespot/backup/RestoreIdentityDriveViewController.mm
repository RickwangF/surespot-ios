//
//  RestoreIdentityViewController.m
//  surespot
//
//  Created by Adam on 11/28/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "RestoreIdentityDriveViewController.h"
#import "GTLRDrive.h"
#import "CocoaLumberjack.h"
#import "SurespotConstants.h"
#import "IdentityCell.h"
#import "IdentityController.h"
#import "FileController.h"
#import "UIUtils.h"
#import "LoadingView.h"
#import "NSBundle+FallbackLanguage.h"
#import "SurespotConfiguration.h"
#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import "SurespotAppDelegate.h"
#import <GTMSessionFetcher/GTMSessionFetcher.h>

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

static NSString *const kKeychainItemName = @"Google Drive surespot";
static NSString* const DRIVE_IDENTITY_FOLDER = @"surespot identity backups";
static NSString *const kNewKeychainItemName = @"Google surespot GTMAppAuth";
static NSString *const kRedirectURI = @"com.googleusercontent.apps.428168563991-kjkqs31gov2lmgh05ajbhcpi7bkpuop7:/oauthredirect";

@interface RestoreIdentityDriveViewController ()
@property (strong, nonatomic) IBOutlet UITableView *tvDrive;
@property (nonatomic, strong) GTLRDriveService *driveService;
@property (strong) NSMutableArray * driveIdentities;
@property (strong) NSDateFormatter * dateFormatter;
@property (atomic, strong) id progressView;
@property (atomic, strong) NSString * name;
@property (atomic, strong) NSString * identifier;
@property (atomic, strong) NSString * storedPassword;
- (IBAction)bLoadIdentities:(id)sender;
@property (strong, nonatomic) IBOutlet UIButton *bSelect;
@property (strong, nonatomic) IBOutlet UILabel *accountLabel;
@property (strong, nonatomic) IBOutlet UILabel *labelGoogleDriveBackup;
@end

@implementation RestoreIdentityDriveViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.tabBarController.tabBar.translucent = NO;
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    self.driveService = [[GTLRDriveService alloc] init];
    
    _driveIdentities = [NSMutableArray new];
    _driveService.shouldFetchNextPages = YES;
    _driveService.retryEnabled = YES;
    
    [self setAccountFromKeychain];
    [self loadIdentitiesAuthIfNecessary:NO];
    
    [_tvDrive registerNib:[UINib nibWithNibName:@"IdentityCell" bundle:nil] forCellReuseIdentifier:@"IdentityCell"];
    
    _dateFormatter = [[NSDateFormatter alloc]init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    _labelGoogleDriveBackup.text = NSLocalizedString(@"restore_drive", nil);
    
    [_bSelect.titleLabel setAdjustsFontSizeToFitWidth:YES];
    
    //theme
    if ([UIUtils isBlackTheme]) {
        [self.view setBackgroundColor:[UIColor blackColor]];
        [self.tvDrive setBackgroundColor:[UIColor blackColor]];
        [self.tvDrive setSeparatorColor:[UIUtils surespotSeparatorGrey]];
        [self.tvDrive setSeparatorInset:UIEdgeInsetsZero];
        [self.labelGoogleDriveBackup setTextColor:[UIUtils surespotForegroundGrey]];
        [self.labelGoogleDriveBackup setBackgroundColor:[UIUtils surespotGrey]];
        [self.accountLabel setTextColor:[UIUtils surespotForegroundGrey]];
        //        [self.accountLabel setBackgroundColor:[UIUtils surespotGrey]];
    }
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
    //    if (_driveService.authorizer && [_driveService.authorizer isMemberOfClass:[GTMOAuth2Authentication class]]) {
    //        NSString * currentEmail = [[((GTMOAuth2Authentication *) _driveService.authorizer ) parameters] objectForKey:@"email"];
    //        if (currentEmail) {
    //            _accountLabel.text = currentEmail;
    //            [_bSelect setTitle:NSLocalizedString(@"remove", nil) forState:UIControlStateNormal];
    //            return;
    //
    //        }
    //    }
    
    if (_driveService.authorizer) {
        _accountLabel.text = [_driveService.authorizer userEmail];
        [_bSelect setTitle:NSLocalizedString(@"remove", nil) forState:UIControlStateNormal];
        return;
    }
    
    _accountLabel.text = NSLocalizedString(@"no_google_account_selected", nil);
    [_bSelect setTitle:NSLocalizedString(@"select_google_drive_account", nil) forState:UIControlStateNormal];
    
    [_driveIdentities removeAllObjects];
    [_tvDrive reloadData];
}

// Helper to check if user is authorized
- (BOOL)isAuthorized
{
    return [_driveService.authorizer canAuthorize];
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
                                           [self loadIdentitiesAuthIfNecessary:NO];
                                       } else {
                                           DDLogError(@"Authorization error: %@", [error localizedDescription]);
                                           
                                           [UIUtils showToastMessage:error.localizedDescription duration:2];
                                           
                                           self.driveService.authorizer = nil;
                                           _accountLabel.text = nil;
                                       }
                                       
                                   }];
}

- (IBAction)bLoadIdentities:(id)sender {
    if ([self isAuthorized]) {
        [GTMAppAuthFetcherAuthorization removeAuthorizationFromKeychainForName:kNewKeychainItemName];
        _driveService.authorizer = nil;
        [self updateUI];
    }
    else {
        [self loadIdentitiesAuthIfNecessary:YES];
    }
}

-(void) loadIdentitiesAuthIfNecessary: (BOOL) auth {
    if (![self isAuthorized])
    {
        if (auth) {
            DDLogInfo(@"launching google authorization");
            [self authorize];
        }
        return;
    }
    
    [self retrieveIdentityFilesCompletionBlock:^(id identityFiles) {
        [_driveIdentities removeAllObjects];
        [_driveIdentities addObjectsFromArray:[identityFiles sortedArrayUsingComparator:^(id obj1, id obj2) {
            NSDate *d1 = [obj1 objectForKey:@"date"];
            NSDate *d2 = [obj2 objectForKey:@"date"];
            return [d2 compare:d1];
        }]];
        [_tvDrive reloadData];
    }];
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
                          
                          GTLRDriveQuery_FilesCreate *query = [GTLRDriveQuery_FilesCreate   queryWithObject:folderObj uploadParameters:nil];
                          
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

- (void)retrieveIdentityFilesCompletionBlock:(CallbackBlock) callback {
    _progressView = [LoadingView showViewKey:@"progress_loading_identities"];
    
    [self ensureDriveIdentityDirectoryCompletionBlock:^(NSString * identityDirId) {
        DDLogInfo(@"got identity folder id %@", identityDirId);
        
        if (!identityDirId) {
            DDLogDebug(@"Tearing progress down");
            [_progressView removeView];
            _progressView = nil;
            [UIUtils showToastKey:@"could_not_list_identities_from_google_drive" duration:2];
            callback(nil);
            return;
            
        }
        GTLRDriveQuery_FilesList *queryFilesList = [GTLRDriveQuery_FilesList query];
        
        queryFilesList.q = [NSString stringWithFormat: @"trashed = false and \'%@\' in parents", identityDirId];
        queryFilesList.fields = @"files(id, modifiedTime,originalFilename)";
        
        [_driveService executeQuery:queryFilesList
                  completionHandler:^(GTLRServiceTicket *ticket, GTLRDrive_FileList *result,
                                      NSError *error) {
                      
                      if (error) {
                          DDLogError(@"An error occurred: %@", error);
                          DDLogDebug(@"Tearing progress down");
                          [_progressView removeView];
                          _progressView = nil;
                          [UIUtils showToastKey:@"could_not_list_identities_from_google_drive" duration:2];
                          callback(nil);
                          return;
                      }
                      
                      DDLogInfo(@"retrieved Identity files %@", result.files);
                      NSInteger dlCount = result.files.count;
                      if (dlCount == 0) {
                          //no identities to download
                          DDLogDebug(@"Tearing progress down");
                          [_progressView removeView];
                          _progressView = nil;
                          callback(nil);
                          return;
                      }
                      
                      NSMutableArray * identityFiles = [NSMutableArray new];
                      
                      for (GTLRDrive_File *file in result.files) {
                          DDLogInfo(@"file name = %@", file.originalFilename);
                          NSMutableDictionary * identityFile = [NSMutableDictionary new];
                          [identityFile  setObject: [[IdentityController sharedInstance] identityNameFromFile: file.originalFilename] forKey:@"name"];
                          [identityFile setObject:[file.modifiedTime date] forKey:@"date"];
                          [identityFile setObject:file.identifier forKey:@"identifier"];
                          [identityFiles addObject:identityFile];
                      }
                      DDLogDebug(@"Tearing progress down");
                      [_progressView removeView];
                      _progressView = nil;
                      callback(identityFiles);
                      
                  }];
        
        
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _driveIdentities.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"IdentityCell";
    
    IdentityCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSDictionary *file = [self.driveIdentities objectAtIndex:indexPath.row];
    cell.nameLabel.text = [file objectForKey:@"name"];
    cell.dateLabel.text = [[_dateFormatter stringFromDate: [file objectForKey:@"date"]] stringByReplacingOccurrencesOfString:@"," withString:@""];
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
    bgColorView.layer.masksToBounds = YES;
    cell.selectedBackgroundView = bgColorView;
    cell.backgroundColor = [UIColor clearColor];
    if ([UIUtils isBlackTheme]) {
        cell.nameLabel.textColor = [UIUtils surespotForegroundGrey];
        cell.dateLabel.textColor = [UIUtils surespotForegroundGrey];
    }
    
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[IdentityController sharedInstance] getIdentityCount] >= MAX_IDENTITIES) {
        [UIUtils showToastMessage:[NSString stringWithFormat: NSLocalizedString(@"login_max_identities_reached",nil), MAX_IDENTITIES] duration:2];
        return;
    }
    
    NSDictionary * rowData = [_driveIdentities objectAtIndex:indexPath.row];
    NSString * name = [rowData objectForKey:@"name"];
    NSString * identifier = [rowData objectForKey:@"identifier"];
    
    _storedPassword = [[IdentityController sharedInstance] getStoredPasswordForIdentity:name];
    _name = name;
    _identifier = identifier;
    
    [UIUtils showPasswordAlertTitle:[NSString stringWithFormat:NSLocalizedString(@"restore_identity", nil), name]
                            message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name]
                         controller:self callback:^(NSString * password) {
                             if (![UIUtils stringIsNilOrEmpty:password]) {
                                 [self importIdentity:_name identifier:_identifier password:password];
                             }
                         }];
}

-(void) importIdentity: (NSString *) name identifier: (NSString *) identifier password: (NSString *) password {
    DDLogDebug(@"importIdentity");
    DDLogDebug(@"showing progress");
    _progressView = [LoadingView showViewKey:@"progress_restoring_identity"];
    
    GTLRQuery *query = [GTLRDriveQuery_FilesGet queryForMediaWithFileId:identifier];
    [self.driveService executeQuery:query completionHandler:^(GTLRServiceTicket * ticket, GTLRDataObject *file, NSError * _Nullable error) {
        
        if (error == nil) {
            NSData * identityData = [FileController gunzipIfNecessary:file.data];
            [[IdentityController sharedInstance] importIdentityData:identityData username:name password:password callback:^(id result) {
                DDLogDebug(@"Tearing progress down");
                [_progressView removeView];
                _progressView = nil;
                
                //update stored password
                if (![UIUtils stringIsNilOrEmpty:_storedPassword] && ![_storedPassword isEqualToString:password]) {
                    [[IdentityController sharedInstance] storePasswordForIdentity:name password:password];
                }
                
                _storedPassword = nil;
                
                if (result) {
                    [UIUtils showToastMessage:result duration:2];
                }
                else {
                    [UIUtils showToastKey:@"identity_imported_successfully" duration:2];
                    //if we now only have 1 identity, go to login view controller
                    if ([[[IdentityController sharedInstance] getIdentityNames] count] == 1) {
                        UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
                        [self.navigationController setViewControllers:@[[storyboard instantiateViewControllerWithIdentifier:@"loginViewController"]]];
                    }
                }
            }];
        } else {
            DDLogError(@"An error occurred: %@", error);
            DDLogDebug(@"Tearing progress down");
            [_progressView removeView];
            _progressView = nil;
            [UIUtils showToastKey:@"could_not_list_identities_from_google_drive" duration:2];
            _storedPassword = nil;
        }
    }];
    
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}

@end
