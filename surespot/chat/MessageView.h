//
//  OurMessageView.h
//  surespot
//
//  Created by Adam on 10/30/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FilledRectView.h"
#import "UIImageViewAligned.h"
#import "SurespotMessage.h"
#import "ActiveLabel-Swift.h"
#import "GifImageViewAligned.h"

@interface MessageView : UITableViewCell
@property (strong, nonatomic) IBOutlet FilledRectView *messageSentView;
@property (strong, nonatomic) IBOutlet UILabel *messageStatusLabel;
@property (strong, nonatomic) IBOutlet UIImageViewAligned *uiImageView;
@property (strong, nonatomic) IBOutlet ActiveLabel *messageLabel;
@property (strong, nonatomic) IBOutlet UIImageView *audioIcon;
@property (strong, nonatomic) IBOutlet UISlider *audioSlider;
@property (strong, nonatomic) IBOutlet UIImageView *shareableView;
@property (strong, nonatomic) IBOutlet UILabel *messageSize;
@property (strong, nonatomic) IBOutlet GifImageViewAligned *gifView;
@property (weak, nonatomic) SurespotMessage * message;
@end
