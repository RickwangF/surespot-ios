//
//  GalleryView.m
//  surespot
//
//  Created by Adam on 5/10/17.
//  Copyright © 2017 surespot. All rights reserved.
//

#import "GalleryView.h"
#import "NetworkManager.h"
#import "FLAnimatedImage.h"
#import "CocoaLumberjack.h"
#import "GalleryItemView.h"
//#import "GifSearchView+GifCache.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface GalleryView ()

@property (strong, nonatomic) IBOutlet UICollectionView *galleryPreview;

@property (strong, nonatomic) CallbackBlock callback;
@property (strong, nonatomic) NSMutableArray * gifs;
@end

@implementation GalleryView

-(void) awakeFromNib {
    [super awakeFromNib];
    // [_galleryPreview content]
    [_galleryPreview setDelegate:self];
    [_galleryPreview setDataSource:self];
    [_galleryPreview registerNib:[UINib nibWithNibName:@"GifSearchView" bundle:nil] forCellWithReuseIdentifier:@"GifCell"];
    UICollectionViewFlowLayout * layout = [[UICollectionViewFlowLayout alloc] init];
    
    [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
}

- (IBAction)closeButtonTouch:(id)sender {
    [self removeFromSuperview];
}

-(void) searchGifs: (NSString *) query {
    [[[NetworkManager sharedInstance] getNetworkController:nil] searchGiphy:query callback:^(id result) {
        _gifs = [result objectForKey:@"data"];
        [_galleryPreview reloadData];
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
    GalleryItemView* newCell = [self.galleryPreview dequeueReusableCellWithReuseIdentifier:@"Cell"
                                                                          forIndexPath:indexPath];
    
//    [[newCell gifView] setAnimatedImage:nil];
    
    NSDictionary * data = [_gifs objectAtIndex:[indexPath row]];
    NSDictionary * gifData = [[data objectForKey:@"images"] objectForKey:@"fixed_height"];
    NSString * url =[gifData objectForKey:@"url"];
    newCell.url = url;
 //   [newCell setUrl:url retryAttempt:0];
    return newCell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // If you need to use the touched cell, you can retrieve it like so
    GalleryItemView *cell = (GalleryItemView *)[collectionView cellForItemAtIndexPath:indexPath];
    _callback([cell url]);
  
}

@end
