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
#import <Photos/Photos.h>
//#import "GifSearchView+GifCache.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface GalleryView ()

@property (strong, nonatomic) IBOutlet UICollectionView *galleryPreview;

@property (strong, nonatomic) CallbackBlock callback;
@property (strong, nonatomic) PHFetchResult * photos;
@property (assign, nonatomic) NSInteger height;
@end

@implementation GalleryView

-(void) awakeFromNib {
    [super awakeFromNib];
    // [_galleryPreview content]
    [_galleryPreview setDelegate:self];
    [_galleryPreview setDataSource:self];
    [_galleryPreview registerNib:[UINib nibWithNibName:@"GalleryItemView" bundle:nil] forCellWithReuseIdentifier:@"GalleryCell"];
    UICollectionViewFlowLayout * layout = [[UICollectionViewFlowLayout alloc] init];
    
    [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
}

- (IBAction)closeButtonTouch:(id)sender {
    [self removeFromSuperview];
}

-(void) fetchAssetsWithHeight: (NSInteger) height {
    
    DDLogDebug(@"fetching assets with height: %ld", height);
    _height = height;
    
    _photos = [PHAsset fetchAssetsWithOptions:nil];
    [_galleryPreview reloadData];
    
}

-(void) setCallback: (CallbackBlock) callback {
    
    _callback = callback;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [_photos count];
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}


- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset * asset = [_photos objectAtIndex:[indexPath row]];
    DDLogDebug(@"desired height: %ld", _height);
    DDLogDebug(@"size for original item: %@, width: %lu, height: %lu",asset,[asset pixelWidth], (unsigned long)[asset pixelHeight]);
    CGFloat scale = (float) _height / [asset pixelHeight];
    CGFloat width = [asset pixelWidth] *scale;
    CGFloat height = [asset pixelHeight]* scale;
    
    DDLogDebug(@"size for scaled item: %@, width: %f, height: %f, scale: %f", asset, width,height,scale);
    return CGSizeMake( width, height);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    GalleryItemView* newCell = [self.galleryPreview dequeueReusableCellWithReuseIdentifier:@"GalleryCell"
                                                                              forIndexPath:indexPath];
    
    PHAsset * asset = [_photos objectAtIndex:[indexPath row]];
    // NSDictionary * gifData = [[data objectForKey:@"images"] objectForKey:@"fixed_height"];
    
    DDLogDebug(@"cell size for original item: %@, width: %lu, height: %lu",asset,[asset pixelWidth], (unsigned long)[asset pixelHeight]);
    CGFloat scale = _height / [asset pixelHeight];
    CGFloat width = [asset pixelWidth] *scale;
    CGFloat height = [asset pixelHeight]* scale;
    
    DDLogDebug(@"cell size for scaled item: %@, width: %f, height: %f, scale: %f", asset, width,height,scale);
   
    PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.resizeMode   = PHImageRequestOptionsResizeModeFast;
    requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    requestOptions.synchronous = true;
    
    
    [[PHCachingImageManager defaultManager] requestImageForAsset:asset
                                                      targetSize:CGSizeMake( width, height)
                                                     contentMode:PHImageContentModeAspectFit
                                                         options:requestOptions
                                                   resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                                                       DDLogDebug(@"Loaded asset");
                                                       newCell.galleryView.image = result;
                                                   }];
    
    //    NSDictionary * data = [_photos objectAtIndex:[indexPath row]];
    //    NSDictionary * gifData = [[data objectForKey:@"images"] objectForKey:@"fixed_height"];
    //    NSString * url =[gifData objectForKey:@"url"];
    //    newCell.url = url;
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
