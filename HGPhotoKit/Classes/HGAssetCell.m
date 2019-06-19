//
//  HGAssetCell.m
//  HGImagePickerController
//
//  Created by pengweijun on 2019/6/18.
//  Copyright © 2019年 彭伟军. All rights reserved.
//

#import "HGAssetCell.h"
#import "HGAssetModel.h"
#import "UIView+Layout.h"
#import "HGImageManager.h"
#import "HGImagePickerController.h"
#import "HGProgressView.h"
#import <YYKit/UIColor+YYAdd.h>
@interface HGAssetCell ()
@property (weak, nonatomic) UIImageView *imageView;       // The photo / 照片
@property (weak, nonatomic) UIImageView *selectImageView;
@property (weak, nonatomic) UILabel *indexLabel;
@property (weak, nonatomic) UIView *bottomView;

@property (weak, nonatomic) UIImageView *imageTypeIcon;

@property (weak, nonatomic) UILabel *timeLength;
@property (strong, nonatomic) UITapGestureRecognizer *tapGesture;

@property (nonatomic, weak) UIImageView *videoImgView;
@property (nonatomic, strong) HGProgressView *progressView;
@property (nonatomic, assign) int32_t bigImageRequestID;
@end

@implementation HGAssetCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload:) name:@"hg_PHOTO_PICKER_RELOAD_NOTIFICATION" object:nil];
    return self;
}

- (void)setModel:(HGAssetModel *)model {
    _model = model;
    self.representedAssetIdentifier = model.asset.localIdentifier;
    int32_t imageRequestID = [[HGImageManager manager] getPhotoWithAsset:model.asset photoWidth:self.hg_width completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
        // Set the cell's thumbnail image if it's still showing the same asset.
        if ([self.representedAssetIdentifier isEqualToString:model.asset.localIdentifier]) {
            self.imageView.image = photo;
        } else {
            // NSLog(@"this cell is showing other asset");
            [[PHImageManager defaultManager] cancelImageRequest:self.imageRequestID];
        }
        if (!isDegraded) {
            [self hideProgressView];
            self.imageRequestID = 0;
        }
    } progressHandler:nil networkAccessAllowed:NO];
    if (imageRequestID && self.imageRequestID && imageRequestID != self.imageRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:self.imageRequestID];
        // NSLog(@"cancelImageRequest %d",self.imageRequestID);
    }
    self.imageRequestID = imageRequestID;
    self.selectPhotoButton.selected = model.isSelected;
    self.selectImageView.image = self.selectPhotoButton.isSelected ? self.photoSelImage : self.photoDefImage;
    self.indexLabel.hidden = !self.selectPhotoButton.isSelected;
    
    self.type = (NSInteger)model.type;
    // 让宽度/高度小于 最小可选照片尺寸 的图片不能选中
    if (![[HGImageManager manager] isPhotoSelectableWithAsset:model.asset]) {
        if (_selectImageView.hidden == NO) {
            self.selectPhotoButton.hidden = YES;
            _selectImageView.hidden = YES;
        }
    }
    // 如果用户选中了该图片，提前获取一下大图
    if (model.isSelected) {
        [self requestBigImage];
    } else {
        [self cancelBigImageRequest];
    }
    [self setNeedsLayout];
    
    if (self.assetCellDidSetModelBlock) {
        self.assetCellDidSetModelBlock(self, _imageView, _selectImageView, _indexLabel, _bottomView, _timeLength, _videoImgView);
    }
}

- (void)setIndex:(NSInteger)index {
    _index = index;
    self.indexLabel.text = [NSString stringWithFormat:@"%zd", index];
    [self.contentView bringSubviewToFront:self.indexLabel];
}

//- (void)setIsShowWhiteBoard:(BOOL)isShowWhiteBoard{
//    self.whiteboardView.hidden = !isShowWhiteBoard;
//    [self.contentView bringSubviewToFront:self.whiteboardView];
//}

- (void)setShowSelectBtn:(BOOL)showSelectBtn {
    _showSelectBtn = showSelectBtn;
    BOOL selectable = [[HGImageManager manager] isPhotoSelectableWithAsset:self.model.asset];
    if (!self.selectPhotoButton.hidden) {
        self.selectPhotoButton.hidden = !showSelectBtn || !selectable;
    }
    if (!self.selectImageView.hidden) {
        self.selectImageView.hidden = !showSelectBtn || !selectable;
    }
}

- (void)setType:(HGAssetCellType)type {
    _type = type;
    if (type == HGAssetCellTypePhoto || type == HGAssetCellTypeLivePhoto || (type == HGAssetCellTypePhotoGif && !self.allowPickingGif) || self.allowPickingMultipleVideo) {
        _selectImageView.hidden = NO;
        _selectPhotoButton.hidden = NO;
        _bottomView.hidden = YES;
    } else { // Video of Gif
        _selectImageView.hidden = YES;
        _selectPhotoButton.hidden = YES;
    }
    self.imageTypeIcon.hidden = YES;

    if (type == HGAssetCellTypeVideo) {
        self.bottomView.hidden = NO;
        self.timeLength.text = _model.timeLength;
        self.videoImgView.hidden = NO;
        _timeLength.hg_left = self.videoImgView.hg_right;
        _timeLength.textAlignment = NSTextAlignmentRight;
    } else if (type == HGAssetCellTypePhotoGif && self.allowPickingGif) {
        self.bottomView.hidden = YES;
        self.imageTypeIcon.hidden = NO;
        self.timeLength.text = @"GIF";
        self.videoImgView.hidden = YES;
        _timeLength.hg_left = 5;
        _timeLength.textAlignment = NSTextAlignmentLeft;
    }
}

- (void)setAllowPreview:(BOOL)allowPreview {
    _allowPreview = allowPreview;
    if (allowPreview) {
        _imageView.userInteractionEnabled = NO;
        _tapGesture.enabled = NO;
    } else {
        _imageView.userInteractionEnabled = YES;
        _tapGesture.enabled = YES;
    }
}

- (void)selectPhotoButtonClick:(UIButton *)sender {
    if (self.didSelectPhotoBlock) {
        self.didSelectPhotoBlock(sender.isSelected);
    }
    self.selectImageView.image = sender.isSelected ? self.photoSelImage : self.photoDefImage;
    if (sender.isSelected) {
        [UIView showOscillatoryAnimationWithLayer:_selectImageView.layer type:HGOscillatoryAnimationToBigger];
        // 用户选中了该图片，提前获取一下大图
        [self requestBigImage];
    } else { // 取消选中，取消大图的获取
        [self cancelBigImageRequest];
    }
}

/// 只在单选状态且allowPreview为NO时会有该事件
- (void)didTapImageView {
    if (self.didSelectPhotoBlock) {
        self.didSelectPhotoBlock(NO);
    }
}

- (void)hideProgressView {
    if (_progressView) {
        self.progressView.hidden = YES;
        self.imageView.alpha = 1.0;
    }
}

- (void)requestBigImage {
    if (_bigImageRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:_bigImageRequestID];
    }
    
    _bigImageRequestID = [[HGImageManager manager] requestImageDataForAsset:_model.asset completion:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
        [self hideProgressView];
    } progressHandler:^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
        if (self.model.isSelected) {
            progress = progress > 0.02 ? progress : 0.02;;
            self.progressView.progress = progress;
            self.progressView.hidden = NO;
            self.imageView.alpha = 0.4;
            if (progress >= 1) {
                [self hideProgressView];
            }
        } else {
            // 快速连续点几次，会EXC_BAD_ACCESS...
            // *stop = YES;
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            [self cancelBigImageRequest];
        }
    }];
}

- (void)cancelBigImageRequest {
    if (_bigImageRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:_bigImageRequestID];
    }
    [self hideProgressView];
}

#pragma mark - Notification

- (void)reload:(NSNotification *)noti {
    HGImagePickerController *hgImagePickerVc = (HGImagePickerController *)noti.object;
    if (self.model.isSelected && hgImagePickerVc.showSelectedIndex) {
        self.index = [hgImagePickerVc.selectedAssetIds indexOfObject:self.model.asset.localIdentifier] + 1;
    }
    self.indexLabel.hidden = !self.selectPhotoButton.isSelected;
    if (hgImagePickerVc.selectedModels.count >= hgImagePickerVc.maxImagesCount && hgImagePickerVc.showPhotoCannotSelectLayer && !self.model.isSelected) {
        self.cannotSelectLayerButton.backgroundColor = hgImagePickerVc.cannotSelectLayerColor;
        self.cannotSelectLayerButton.hidden = NO;
    } else {
        self.cannotSelectLayerButton.hidden = YES;
    }
}

#pragma mark - Lazy load
//- (UIView *)whiteboardView {
//    if (_whiteboardView == nil) {
//        UIView *whiteboardView = [UIView new];
//        whiteboardView.backgroundColor = [[UIColor whiteColor]colorWithAlphaComponent:0.8f];
//        whiteboardView.userInteractionEnabled = NO;
//        [self.contentView addSubview:whiteboardView];
//        whiteboardView.hidden = YES;
//        _whiteboardView = whiteboardView;
//    }
//    return _whiteboardView;
//}

- (UIButton *)selectPhotoButton {
    if (_selectPhotoButton == nil) {
        UIButton *selectPhotoButton = [[UIButton alloc] init];
        [selectPhotoButton addTarget:self action:@selector(selectPhotoButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:selectPhotoButton];
        _selectPhotoButton = selectPhotoButton;
    }
    return _selectPhotoButton;
}

- (UIImageView *)imageView {
    if (_imageView == nil) {
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        [self.contentView addSubview:imageView];
        _imageView = imageView;
        
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapImageView)];
        [_imageView addGestureRecognizer:_tapGesture];
    }
    return _imageView;
}

- (UIImageView *)selectImageView {
    if (_selectImageView == nil) {
        UIImageView *selectImageView = [[UIImageView alloc] init];
        selectImageView.contentMode = UIViewContentModeCenter;
        selectImageView.clipsToBounds = YES;
        [self.contentView addSubview:selectImageView];
        _selectImageView = selectImageView;
    }
    return _selectImageView;
}

- (UIImageView *)imageTypeIcon {
    if (_imageTypeIcon == nil) {
        UIImageView *imageTypeIcon = [[UIImageView alloc] init];
        imageTypeIcon.contentMode = UIViewContentModeCenter;
        imageTypeIcon.clipsToBounds = YES;
        [imageTypeIcon setImage:[UIImage hg_imageNamedFromMyBundle:@"photo_type_GIF"]];
        [self.contentView addSubview:imageTypeIcon];
        _imageTypeIcon = imageTypeIcon;
    }
    return _imageTypeIcon;
}

- (UIView *)bottomView {
    if (_bottomView == nil) {
        UIView *bottomView = [[UIView alloc] init];
        static NSInteger rgb = 0;
        bottomView.backgroundColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:0.8];
        [self.contentView addSubview:bottomView];
        _bottomView = bottomView;
    }
    return _bottomView;
}

- (UIButton *)cannotSelectLayerButton {
    if (_cannotSelectLayerButton == nil) {
        UIButton *cannotSelectLayerButton = [[UIButton alloc] init];
        cannotSelectLayerButton.userInteractionEnabled = NO;
        [self.contentView addSubview:cannotSelectLayerButton];
        _cannotSelectLayerButton = cannotSelectLayerButton;
    }
    return _cannotSelectLayerButton;
}

- (UIImageView *)videoImgView {
    if (_videoImgView == nil) {
        UIImageView *videoImgView = [[UIImageView alloc] init];
        [videoImgView setImage:[UIImage hg_imageNamedFromMyBundle:@"VideoSendIcon"]];
        [self.bottomView addSubview:videoImgView];
        _videoImgView = videoImgView;
    }
    return _videoImgView;
}

- (UILabel *)timeLength {
    if (_timeLength == nil) {
        UILabel *timeLength = [[UILabel alloc] init];
        timeLength.font = [UIFont boldSystemFontOfSize:11];
        timeLength.textColor = [UIColor whiteColor];
        timeLength.textAlignment = NSTextAlignmentRight;
        [self.bottomView addSubview:timeLength];
        _timeLength = timeLength;
    }
    return _timeLength;
}

- (UILabel *)indexLabel {
    if (_indexLabel == nil) {
        UILabel *indexLabel = [[UILabel alloc] init];
        indexLabel.font = [UIFont systemFontOfSize:14];
        indexLabel.textColor = [UIColor whiteColor];
        indexLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:indexLabel];
        _indexLabel = indexLabel;
    }
    return _indexLabel;
}

- (HGProgressView *)progressView {
    if (_progressView == nil) {
        _progressView = [[HGProgressView alloc] init];
        _progressView.hidden = YES;
        [self addSubview:_progressView];
    }
    return _progressView;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _cannotSelectLayerButton.frame = self.bounds;
    if (self.allowPreview) {
        _selectPhotoButton.frame = CGRectMake(self.hg_width - 44, 0, 44, 44);
    } else {
        _selectPhotoButton.frame = self.bounds;
    }
    _selectImageView.frame = CGRectMake(self.hg_width - 27, 3, 24, 24);
    if (_selectImageView.image.size.width <= 27) {
        _selectImageView.contentMode = UIViewContentModeCenter;
    } else {
        _selectImageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    _indexLabel.frame = _selectImageView.frame;
    _imageView.frame = CGRectMake(0, 0, self.hg_width, self.hg_height);
    
    static CGFloat progressWH = 20;
    CGFloat progressXY = (self.hg_width - progressWH) / 2;
    _progressView.frame = CGRectMake(progressXY, progressXY, progressWH, progressWH);

    _bottomView.frame = CGRectMake(0, self.hg_height - 17, self.hg_width, 17);
    _videoImgView.frame = CGRectMake(8, 0, 17, 17);
    _timeLength.frame = CGRectMake(self.videoImgView.hg_right, 0, self.hg_width - self.videoImgView.hg_right - 5, 17);
    _imageTypeIcon.frame = CGRectMake(6, self.hg_height - 14.1 - 5.7, 25, 14.1);
    
    self.type = (NSInteger)self.model.type;
    self.showSelectBtn = self.showSelectBtn;
    
    [self.contentView bringSubviewToFront:_bottomView];
    [self.contentView bringSubviewToFront:_cannotSelectLayerButton];
    [self.contentView bringSubviewToFront:_selectPhotoButton];
    [self.contentView bringSubviewToFront:_selectImageView];
    [self.contentView bringSubviewToFront:_indexLabel];
    
    if (self.assetCellDidLayoutSubviewsBlock) {
        self.assetCellDidLayoutSubviewsBlock(self, _imageView, _selectImageView, _indexLabel, _bottomView, _timeLength, _videoImgView);
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@interface HGAlbumCell ()
@property (weak, nonatomic) UIImageView *posterImageView;
@property (weak, nonatomic) UILabel *titleLabel;
@property (weak, nonatomic) UILabel *subTitleLabel;
@property (strong, nonatomic) UIView *lineView;
@end

@implementation HGAlbumCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    [self.contentView addSubview:self.lineView];
    return self;
}

- (void)setModel:(HGAlbumModel *)model {
    _model = model;
    
    self.titleLabel.text = model.name;
    self.subTitleLabel.text = [NSString stringWithFormat:@"%zd",model.count];
//    NSMutableAttributedString *nameString = [[NSMutableAttributedString alloc] initWithString:model.name attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16],NSForegroundColorAttributeName:[UIColor blackColor]}];
//    NSAttributedString *countString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"  (%zd)",model.count] attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16],NSForegroundColorAttributeName:[UIColor lightGrayColor]}];
//    [nameString appendAttributedString:countString];
//    self.titleLabel.attributedText = nameString;
    [[HGImageManager manager] getPostImageWithAlbumModel:model completion:^(UIImage *postImage) {
        self.posterImageView.image = postImage;
    }];
//    if (model.selectedCount) {
//        self.selectedCountButton.hidden = NO;
//        [self.selectedCountButton setTitle:[NSString stringWithFormat:@"%zd",model.selectedCount] forState:UIControlStateNormal];
//    } else {
//        self.selectedCountButton.hidden = YES;
//    }
    self.lineView.hg_bottom = self.hg_height;
    [self.contentView bringSubviewToFront:self.lineView];
    if (self.albumCellDidSetModelBlock) {
        self.albumCellDidSetModelBlock(self, _posterImageView, _titleLabel);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
//    _selectedCountButton.frame = CGRectMake(self.contentView.hg_width - 24, 23, 24, 24);
//    NSInteger titleHeight = ceil(self.titleLabel.font.lineHeight);
    
    self.titleLabel.frame = CGRectMake(self.posterImageView.hg_right + 10, 10, self.hg_width - self.posterImageView.hg_right - 10 - 26 - 6, 19);
    
    self.subTitleLabel.frame = CGRectMake(self.posterImageView.hg_right + 10, self.titleLabel.hg_bottom +10, 100, 16);

    self.posterImageView.frame = CGRectMake(16, 10, 60, 60);
    self.lineView.frame = CGRectMake(self.posterImageView.hg_right + 10,self.hg_height - 1, self.hg_width - (self.posterImageView.hg_right + 10),1);
    
    if (self.albumCellDidLayoutSubviewsBlock) {
        self.albumCellDidLayoutSubviewsBlock(self, _posterImageView, _titleLabel);
    }
}

- (void)layoutSublayersOfLayer:(CALayer *)layer {
    [super layoutSublayersOfLayer:layer];
}

#pragma mark - Lazy load
- (UIView *)lineView {
    if (!_lineView) {
        _lineView = [[UIView alloc] init];
        _lineView.backgroundColor = UIColorHex(EBEBEB);
    }
    return _lineView;
}

- (UIImageView *)posterImageView {
    if (_posterImageView == nil) {
        UIImageView *posterImageView = [[UIImageView alloc] init];
        posterImageView.contentMode = UIViewContentModeScaleAspectFill;
        posterImageView.clipsToBounds = YES;
        [self.contentView addSubview:posterImageView];
        _posterImageView = posterImageView;
    }
    return _posterImageView;
}

- (UILabel *)titleLabel {
    if (_titleLabel == nil) {
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        titleLabel.textColor = [UIColor colorWithHexString:@"#191919"];
        titleLabel.textAlignment = NSTextAlignmentLeft;
        [self.contentView addSubview:titleLabel];
        _titleLabel = titleLabel;
    }
    return _titleLabel;
}

- (UILabel *)subTitleLabel {
    if (_subTitleLabel == nil) {
        UILabel *subTitleLabel = [[UILabel alloc] init];
        subTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        subTitleLabel.textColor = [UIColor colorWithHexString:@"#A9A9A9"];
        subTitleLabel.textAlignment = NSTextAlignmentLeft;
        [self.contentView addSubview:subTitleLabel];
        _subTitleLabel = subTitleLabel;
    }
    return _subTitleLabel;
}

//- (UIButton *)selectedCountButton {
//    if (_selectedCountButton == nil) {
//        UIButton *selectedCountButton = [[UIButton alloc] init];
//        selectedCountButton.layer.cornerRadius = 12;
//        selectedCountButton.clipsToBounds = YES;
//        selectedCountButton.backgroundColor = [UIColor redColor];
//        [selectedCountButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
//        selectedCountButton.titleLabel.font = [UIFont systemFontOfSize:15];
//        [self.contentView addSubview:selectedCountButton];
//        _selectedCountButton = selectedCountButton;
//    }
//    return _selectedCountButton;
//}

@end



@implementation HGAssetCameraCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        _imageView = [[UIImageView alloc] init];
        _imageView.backgroundColor = [UIColor colorWithWhite:1.000 alpha:0.500];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self.contentView addSubview:_imageView];
        self.clipsToBounds = YES;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _imageView.frame = self.bounds;
}

@end
