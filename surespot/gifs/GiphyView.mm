//
//  GiphyView.m
//  surespot
//
//  Created by Adam on 5/10/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import "GiphyView.h"
#import "NetworkManager.h"
#import "FLAnimatedImage.h"
#import "CocoaLumberjack.h"
#import "GifSearchView.h"
#import "GifSearchView+GifCache.h"
#import "UIUtils.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface GiphyView ()

@property (strong, nonatomic) IBOutlet UICollectionView *giphyPreview;

@property (strong, nonatomic) CallbackBlock callback;
@property (strong, nonatomic) NSMutableArray * gifs;
@property (strong, nonatomic) IBOutlet UILabel *backgroundView;
@property (strong, nonatomic) NSString * username;
@end

@implementation GiphyView

-(void) awakeFromNib {
    [super awakeFromNib];
    [_giphyPreview setDelegate:self];
    [_giphyPreview setDataSource:self];
    [_giphyPreview registerNib:[UINib nibWithNibName:@"GifSearchView" bundle:nil] forCellWithReuseIdentifier:@"GifCell"];
    UICollectionViewFlowLayout * layout = [[UICollectionViewFlowLayout alloc] init];
    [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
}

- (IBAction)closeButtonTouch:(id)sender {
    [self removeFromSuperview];
}

-(void) searchGifs: (NSString *) query {
    [self setPreSearchBackground];
    [[[NetworkManager sharedInstance] getNetworkController:nil] searchGiphy:query callback:^(id result) {
        _gifs = [[NSMutableArray alloc] init];
        
        for (NSDictionary * o : [result objectForKey:@"data"]) {
            [_gifs addObject:[[o objectForKey: @"images"] objectForKey: @"fixed_height"]];
        }
        
        [self setPostSearchBackground:NO];
        [_giphyPreview reloadData];
    }];
}

-(void) setCallback: (CallbackBlock) callback {
    
    _callback = callback;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [_gifs count];
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 2;
}


- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary * gifData = [_gifs objectAtIndex:[indexPath row]];
    CGFloat width = [[gifData objectForKey:@"width"] intValue] / [[UIScreen mainScreen] scale];
    CGFloat height = [[gifData objectForKey:@"height"] intValue] / [[UIScreen mainScreen] scale];
    
    DDLogVerbose(@"item: %ld, width: %f, height: %f", [indexPath row], width,height);
    return CGSizeMake( width, height);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    GifSearchView* newCell = [self.giphyPreview dequeueReusableCellWithReuseIdentifier:@"GifCell"
                                                                          forIndexPath:indexPath];
    
    [[newCell gifView] setAnimatedImage:nil];
    
    NSDictionary * gifData = [_gifs objectAtIndex:[indexPath row]];
    NSString * url =[gifData objectForKey:@"url"];
    newCell.url = url;
    [newCell setUrl:url retryAttempt:0];
    return newCell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary * gifData = [_gifs objectAtIndex:[indexPath row]];
    //save recently used info
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSString * key = [NSString stringWithFormat:@"%@%@", _username, @"_recently_used_gifs"];
    NSMutableArray * recentlyUsedGifs = [NSMutableArray arrayWithArray: [defaults objectForKey:key]];
    if (!recentlyUsedGifs) {
        recentlyUsedGifs = [[NSMutableArray alloc] init];
    }
    [recentlyUsedGifs removeObject:gifData];
    [recentlyUsedGifs insertObject:gifData atIndex:0];
    [defaults setObject:recentlyUsedGifs forKey:key];
    
    // If you need to use the touched cell, you can retrieve it like so
    GifSearchView *cell = (GifSearchView *)[collectionView cellForItemAtIndexPath:indexPath];
    _callback([cell url]);
    
}

-(void) loadRecentGifs:(NSString *)username {
    [self setPreSearchBackground];
    _username = username;
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSString * key = [NSString stringWithFormat:@"%@%@", username, @"_recently_used_gifs"];
    _gifs = [defaults objectForKey:key];
    [self setPostSearchBackground:YES];
       [_giphyPreview reloadData];
    
}

-(void) setPreSearchBackground {
    UIActivityIndicatorView * activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:([UIUtils isBlackTheme] ?  UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray)];
    activityIndicator.center = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    [activityIndicator startAnimating];
    _giphyPreview.backgroundView = activityIndicator;
}

-(void) setPostSearchBackground: (BOOL) recentlyUsed {
    if (_gifs.count == 0) {
        _backgroundView.text = NSLocalizedString(recentlyUsed ? @"no_recently_used_gifs" : @"no_gifs_found", nil);
        _backgroundView.textColor = [UIUtils getTextColor];
        _giphyPreview.backgroundView = _backgroundView;
    }
    else {
        _giphyPreview.backgroundView = nil;
    }

}
@end
