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
@end

@implementation GiphyView

-(void) awakeFromNib {
    [super awakeFromNib];
    // [_giphyPreview content]
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
    [[[NetworkManager sharedInstance] getNetworkController:nil] searchGiphy:query callback:^(id result) {
        _gifs = [result objectForKey:@"data"];
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
    return 0;
}


- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary * data = [_gifs objectAtIndex:[indexPath row]];
    NSDictionary * gifData = [[data objectForKey:@"images"] objectForKey:@"fixed_height"];
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
    
    NSDictionary * data = [_gifs objectAtIndex:[indexPath row]];
    NSDictionary * gifData = [[data objectForKey:@"images"] objectForKey:@"fixed_height"];
    NSString * url =[gifData objectForKey:@"url"];
    newCell.url = url;
    [newCell setUrl:url retryAttempt:0];
    return newCell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // If you need to use the touched cell, you can retrieve it like so
    GifSearchView *cell = (GifSearchView *)[collectionView cellForItemAtIndexPath:indexPath];
    _callback([cell url]);
  
}

@end
