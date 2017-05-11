//
//  UIView+giphyView.m
//  surespot
//
//  Created by Adam on 5/10/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import "GiphyView.h"
#import "NetworkManager.h"
#import "FLAnimatedImage.h"
#import "CocoaLumberjack.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface GiphyView ()
@property (strong, nonatomic) IBOutlet UITextField *giphySearchView;
@property (strong, nonatomic) IBOutlet UILabel *giphyLastSearch;
@property (strong, nonatomic) IBOutlet UIScrollView *giphyPreview;
@property (strong, nonatomic) IBOutlet UIScrollView *giphySearches;
@property (strong, nonatomic) NSMapTable *gifViewMap;                                                         
@property (strong, nonatomic) CallbackBlock callback;
@end

@implementation GiphyView


//-(id) initWithFrame:(CGRect)frame {
//    self = [super initWithFrame:frame];
//    id mainView;
//    if (self) {
//        NSArray *subviewArray = [[NSBundle mainBundle] loadNibNamed:@"GiphyView" owner:self options:nil];
//        mainView = [subviewArray objectAtIndex:0];
//        [self addSubview:mainView];
//
//    }
//    return self;
//}


- (IBAction)closeButtonTouch:(id)sender {
    [self removeFromSuperview];
}

-(void) searchGifs: (NSString *) query {
    [[[NetworkManager sharedInstance] getNetworkController:nil] searchGiphy:query callback:^(id result) {
        //  DDLogDebug(@"gif search results: %@", result);
        self.gifViewMap = [NSMapTable weakToStrongObjectsMapTable];
        [self filterGifs:result];
    }];
}

-(void) filterGifs: (NSDictionary *) searchResults {
    CGFloat cx = 0;
    NSArray * data = [searchResults objectForKey:@"data"];
    
    
    for (NSDictionary * result in data) {
        NSDictionary * gifData = [[result objectForKey:@"images"] objectForKey:@"fixed_height"];
        
        FLAnimatedImage * image = [FLAnimatedImage animatedImageWithGIFData:[NSData dataWithContentsOfURL: [NSURL URLWithString:[gifData objectForKey:@"url"]]]];
        
        DDLogDebug(@"image Width: %f, image Height: %f, data Width: %@, Data Height: %@, screen scale: %f", image.size.width, image.size.height, [gifData objectForKey:@"width"], [gifData objectForKey:@"height"],  [[UIScreen mainScreen] scale]);
        
        FLAnimatedImageView * gifView =  [[FLAnimatedImageView alloc] initWithFrame:CGRectMake(cx, 0, [[gifData objectForKey:@"width"] intValue]  / [[UIScreen mainScreen] scale], [[gifData objectForKey:@"height"] intValue] / [[UIScreen mainScreen] scale]) ];
        
        gifView.userInteractionEnabled = YES;
        gifView.animatedImage = image;
        cx += gifView.frame.size.width;
        
        [_gifViewMap setObject:gifData forKey:gifView];
        
        [gifView addGestureRecognizer: [[UITapGestureRecognizer alloc]
                                        initWithTarget:self
                                                action:@selector(handleSingleTap:)]];
        
        [_giphyPreview addSubview:gifView];
        [_giphyPreview setContentSize:CGSizeMake(cx, _giphyPreview.bounds.size.height)] ;
    }
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer
{
    _callback([_gifViewMap objectForKey:recognizer.view]);
}

-(void) setCallback: (CallbackBlock) callback {
    
    _callback = callback;
}

@end
