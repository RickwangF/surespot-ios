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
#import "CHTCollectionViewWaterfallLayout.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface GalleryView ()

@property (strong, nonatomic) IBOutlet UICollectionView *galleryPreview;

@property (strong, nonatomic) CallbackBlock callback;
@property (strong, nonatomic) PHFetchResult * photos;
@end

@implementation GalleryView

-(void) awakeFromNib {
    [super awakeFromNib];
    [_galleryPreview setDelegate:self];
    [_galleryPreview setDataSource:self];
    [_galleryPreview registerNib:[UINib nibWithNibName:@"GalleryItemView" bundle:nil] forCellWithReuseIdentifier:@"GalleryCell"];
    CHTCollectionViewWaterfallLayout *layout = [[CHTCollectionViewWaterfallLayout alloc] init];
    layout.columnCount = 2;
    layout.minimumInteritemSpacing = 2;
    layout.minimumColumnSpacing = 2;
    [_galleryPreview setCollectionViewLayout:layout];
}

- (IBAction)closeButtonTouch:(id)sender {
    [self removeFromSuperview];
}

-(void) fetchAssets {
    PHFetchOptions * options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:NO]];
    _photos = [PHAsset fetchAssetsWithOptions:options];
    [_galleryPreview reloadData];
}

-(void) setCallback: (CallbackBlock) callback {
    
    _callback = callback;
}


- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return  [_photos count];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index =  [indexPath row];
    PHAsset * asset = [_photos objectAtIndex:index];
    return CGSizeMake( [asset pixelWidth], [asset pixelHeight]);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    GalleryItemView* newCell = [self.galleryPreview dequeueReusableCellWithReuseIdentifier:@"GalleryCell"
                                                                              forIndexPath:indexPath];
    NSInteger index =[indexPath row];
    PHAsset * asset = [_photos objectAtIndex: index];
    
    CGFloat screenWidth = [[UIScreen mainScreen] applicationFrame].size.width;
    CGFloat scale = (float) screenWidth / [asset pixelWidth];
    CGFloat width = [asset pixelWidth] * scale;
    CGFloat height = [asset pixelHeight] * scale;
    
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
    
    return newCell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index =[indexPath row];
    PHAsset * asset = [_photos objectAtIndex: index];
    
    if (_callback) {
        _callback ([asset localIdentifier]);
    }
}

@end
