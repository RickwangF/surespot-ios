//
//  QRInviteViewController.m
//  surespot
//
//  Created by Adam on 12/24/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "QRInviteViewController.h"
#import "SurespotConstants.h"
#import "NSBundle+FallbackLanguage.h"
#import "UIUtils.h"
#import "SurespotConfiguration.h"

@interface QRInviteViewController ()
@property (strong, nonatomic) IBOutlet UITextView *inviteBlurb;
@property (strong, nonatomic) IBOutlet UIImageView *inviteImage;
@property (strong, nonatomic) NSString * username;
@end

@implementation QRInviteViewController

- (id)initWithNibName:(NSString *)nibNameOrNil username: (NSString *) username
{
    self = [super initWithNibName:nibNameOrNil bundle:nil];
    if (self) {
        // Custom initialization
        _username = username;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"qr";
    
    NSString * preString = NSLocalizedString(@"qr_pre_username_help", nil);
    NSString * inviteText = [NSString stringWithFormat:@"%@ %@ %@", preString, _username, NSLocalizedString(@"qr_post_username_help", nil)];
    
    NSMutableAttributedString * inviteString = [[NSMutableAttributedString alloc] initWithString:inviteText ];
    
    
    
    //theme
    if ([UIUtils isBlackTheme]) {
        [self.view setBackgroundColor:[UIColor blackColor]];
        [inviteString addAttribute:NSForegroundColorAttributeName value:[UIUtils surespotForegroundGrey] range:NSMakeRange(0,inviteString.length)];
    }
    
    [inviteString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(preString.length+1, _username.length)];
    
    
    _inviteBlurb.attributedText = inviteString;
    [_inviteBlurb setFont:[UIFont systemFontOfSize:17]];
    [_inviteBlurb setTextAlignment:NSTextAlignmentCenter];
    [_inviteImage setImage:[self generateQRInviteImage:_username]];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

-(UIImage *) generateQRInviteImage: (NSString *) username {
    int qrcodeImageDimension = 250;
    NSString * inviteUrl = [NSString stringWithFormat:@"%@/%@%@", [[SurespotConfiguration sharedInstance] baseUrl], [username stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], @"/qr_ios"];
    
    
    // Generation of QR code image
    NSData *qrCodeData = [inviteUrl dataUsingEncoding:NSUTF8StringEncoding]; // recommended encoding
    CIFilter *qrCodeFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [qrCodeFilter setValue:qrCodeData forKey:@"inputMessage"];
    [qrCodeFilter setValue:@"L" forKey:@"inputCorrectionLevel"]; //default of L,M,Q & H modes
    
    CIImage *qrCodeImage = qrCodeFilter.outputImage;
    
    CGRect imageSize = CGRectIntegral(qrCodeImage.extent); // generated image size
    CGSize outputSize = CGSizeMake(qrcodeImageDimension, qrcodeImageDimension); // required image size
    CIImage *imageByTransform = [qrCodeImage imageByApplyingTransform:CGAffineTransformMakeScale(outputSize.width/CGRectGetWidth(imageSize), outputSize.height/CGRectGetHeight(imageSize))];
    
    UIImage *qrCodeImageByTransform = [UIImage imageWithCIImage:imageByTransform];
    return qrCodeImageByTransform;
}

@end
