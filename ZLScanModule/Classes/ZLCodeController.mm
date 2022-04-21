//
//  ZLCodeController.m
//  OpenCVDemo
//
//  Created by lylaut on 2022/2/17.
//

#import "ZLCodeController.h"
#include <opencv2/core.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/wechat_qrcode.hpp>
#include <opencv2/CvCamera2.h>
#include <opencv2/Mat.h>
#include <opencv2/barcode.hpp>
#include <iostream>
#include <vector>
#import <PhotosUI/PhotosUI.h>
#import <CoreImage/CoreImage.h>
#import <AVFoundation/AVFoundation.h>

@interface ZLCodeController () <CvVideoCameraDelegate2, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate> {
    BOOL _navigationBarHidden;
    cv::Ptr<cv::wechat_qrcode::WeChatQRCode> detector;
    cv::Ptr<cv::barcode::BarcodeDetector> barcodeDet;
    
    CvVideoCamera2 *camera;
    int qrScanCount;
    
    BOOL firstStartScanLineAnimation;
    BOOL scanLineAnimationing;
}

@property (nonatomic, weak) UIButton *backButton;

@property (nonatomic, weak) UIButton *torchButton;

@property (nonatomic, strong) NSMutableArray<NSString *> *codes;

@property (nonatomic, strong) AVAudioPlayer *mPlayer;

@property (nonatomic, weak) UIImageView *scanLineView;

@end

@implementation ZLCodeController

- (BOOL)isCameraAvailable {
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}
  
// 前面的摄像头是否可用
- (BOOL)isFrontCameraAvailable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
}
  
// 后面的摄像头是否可用
- (BOOL)isRearCameraAvailable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
}

+ (cv::Mat)cvMatFromUIImage:(UIImage *)image {
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast;
    int type = 0;
    if (CGColorSpaceGetModel(colorSpace) == 0) {
        bitmapInfo = kCGImageAlphaNone;
        type = CV_8UC1;
    } else {
        bitmapInfo = kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault;
        type = CV_8UC4;
    }
    cv::Mat cvMat(rows, cols, type); // 8 bits per component, 4 channels (color channels + alpha)

    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,  // Pointer to  data
                                     cols,                       // Width of bitmap
                                     rows,                       // Height of bitmap
                                     8,                          // Bits per component
                                     cvMat.step[0],              // Bytes per row
                                     colorSpace,                 // Colorspace
                                     bitmapInfo);                // Bitmap info flags

    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);

    return cvMat;
}

- (void)dealloc {
    camera = nil;
    _mPlayer = nil;
    detector.release();
    barcodeDet.release();
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController) {
        _navigationBarHidden = self.navigationController.navigationBarHidden;
        self.navigationController.navigationBarHidden = YES;
    }
    if (!camera.running) {
        camera.delegate = self;
        [camera start];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.navigationController) {
        self.navigationController.navigationBarHidden = _navigationBarHidden;
    }
    if (camera && camera.running) {
        camera.delegate = nil;
        [camera stop];
    }
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
    return NO;
}

//- (UIInterfaceOrientation)orientationByTransforming:(CGAffineTransform)transform {
//  CGFloat angle = atan2f(transform.b, transform.a);
//  NSInteger multiplier = (NSInteger)roundf(angle / M_PI_2);
//  UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
//  if (multiplier < 0) {
//    // clockwise rotation
//    while (multiplier++ < 0) {
//      switch (orientation) {
//        case UIInterfaceOrientationPortrait:
//          orientation = UIInterfaceOrientationLandscapeLeft;
//          break;
//        case UIInterfaceOrientationLandscapeLeft:
//          orientation = UIInterfaceOrientationPortraitUpsideDown;
//          break;
//        case UIInterfaceOrientationPortraitUpsideDown:
//          orientation = UIInterfaceOrientationLandscapeRight;
//          break;
//        case UIInterfaceOrientationLandscapeRight:
//          orientation = UIInterfaceOrientationPortrait;
//          break;
//        default:
//          break;
//      }
//    }
//  } else if (multiplier > 0) {
//    // counter-clockwise rotation
//    while (multiplier-- > 0) {
//      switch (orientation) {
//        case UIInterfaceOrientationPortrait:
//          orientation = UIInterfaceOrientationLandscapeRight;
//          break;
//        case UIInterfaceOrientationLandscapeRight:
//          orientation = UIInterfaceOrientationPortraitUpsideDown;
//          break;
//        case UIInterfaceOrientationPortraitUpsideDown:
//          orientation = UIInterfaceOrientationLandscapeLeft;
//          break;
//        case UIInterfaceOrientationLandscapeLeft:
//          orientation = UIInterfaceOrientationPortrait;
//          break;
//        default:
//          break;
//      }
//    }
//  }
//  return (UIInterfaceOrientation)orientation;
//}

//- (void)viewWillTransitionToSize:(CGSize)size
//       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
//    // 记录当前是横屏还是竖屏
//    BOOL isLandscape = size.width == MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
//
//    // 翻转的时间
//    CGFloat duration = [coordinator transitionDuration];
//    UIInterfaceOrientation orientation = [self orientationByTransforming:[coordinator targetTransform]];
//
//}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor blackColor];
    
    CGFloat WH = 44;
    UIEdgeInsets safeAreaInsets = [UIApplication sharedApplication].keyWindow.safeAreaInsets;
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(safeAreaInsets.left + 15, safeAreaInsets.top + 15, WH, WH)];
    [button setImage:[UIImage imageNamed:@"zl_scan.bundle/back" inBundle:[NSBundle bundleForClass:[ZLCodeController class]]  compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(backBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    self.backButton = button;
    
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusRestricted || status == AVAuthorizationStatusDenied) {
        if (self.delegate) {
            [self.delegate ZLCodeControllerHandleCamaraDenied:self];
        }
        return;
    }
    if (!([self isCameraAvailable] && [self isRearCameraAvailable])) {
        if (self.delegate) {
            [self.delegate ZLCodeControllerHandleCamaraNotSupported:self];
        }
        return;
    }
    qrScanCount = 0;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *basePath = [NSBundle bundleForClass:[ZLCodeController class]].resourcePath;
        const char *sr_prototxt = [basePath stringByAppendingFormat:@"/zl_scan.bundle/%@", @"sr.prototxt"].UTF8String;
        const char *sr_caffemodel = [basePath stringByAppendingFormat:@"/zl_scan.bundle/%@", @"sr.caffemodel"].UTF8String;
        try {
            self->detector = cv::makePtr<cv::wechat_qrcode::WeChatQRCode>([basePath stringByAppendingFormat:@"/zl_scan.bundle/%@", @"detect.prototxt"].UTF8String, [basePath stringByAppendingFormat:@"/zl_scan.bundle/%@", @"detect.caffemodel"].UTF8String, sr_prototxt, sr_caffemodel);
        } catch (const std::exception& e) {
            std::cout <<
                "\n---------------------------------------------------------------\n"
                "Failed to initialize WeChatQRCode.\n"
                "Please, download 'detector.*' and 'sr.*' from\n"
                "https://github.com/WeChatCV/opencv_3rdparty/tree/wechat_qrcode\n"
                "and put them into the current directory.\n"
                "---------------------------------------------------------------\n";
            std::cout << e.what() << std::endl;
            return;
        }
        
        try {
            self->barcodeDet = cv::makePtr<cv::barcode::BarcodeDetector>(sr_prototxt, sr_caffemodel);
        } catch (const std::exception& e) {
            std::cout <<
                     "\n---------------------------------------------------------------\n"
                     "Failed to initialize super resolution.\n"
                     "Please, download 'sr.*' from\n"
                     "https://github.com/WeChatCV/opencv_3rdparty/tree/wechat_qrcode\n"
                     "and put them into the current directory.\n"
                     "Or you can leave sr_prototxt and sr_model unspecified.\n"
                     "---------------------------------------------------------------\n";
            std::cout << e.what() << std::endl;
        }
    });
    
    self.codes = [NSMutableArray arrayWithCapacity:4];
    
    firstStartScanLineAnimation = YES;
    camera = [[CvVideoCamera2 alloc] initWithParentView:self.view];
    camera.delegate = self;
    [camera start];
    
    {
        UIImageView *scanLineView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"zl_scan.bundle/scan_line" inBundle:[NSBundle bundleForClass:[ZLCodeController class]] compatibleWithTraitCollection:nil]];
        CGFloat scanLineViewW = [UIScreen mainScreen].bounds.size.width - 70;
        CGFloat scanLineViewH = scanLineViewW * 18.0 / 360;
        CGFloat scanLineViewY = ([UIScreen mainScreen].bounds.size.height - scanLineViewH) * 0.5 - 150;
        scanLineView.frame = CGRectMake(35, scanLineViewY, scanLineViewW, scanLineViewH);
        [self.view addSubview:scanLineView];
        self.scanLineView = scanLineView;
    }
    
    {
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(([UIScreen mainScreen].bounds.size.width - WH) * 0.5, [UIScreen mainScreen].bounds.size.height * 0.7, WH, WH)];
        [button setImage:[UIImage imageNamed:@"zl_scan.bundle/torch_on" inBundle:[NSBundle bundleForClass:[ZLCodeController class]] compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(torchBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        button.hidden = YES;
        [self.view addSubview:button];
        self.torchButton = button;
    }
    
    {
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - WH - 15, [UIScreen mainScreen].bounds.size.height * 0.7, WH, WH)];
        [button setImage:[UIImage imageNamed:@"zl_scan.bundle/photo_select" inBundle:[NSBundle bundleForClass:[ZLCodeController class]] compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(showImagePicker) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    }
    
    [self.view bringSubviewToFront:self.backButton];
}

- (void)addScanAnimation {
    if (scanLineAnimationing) {
        return;
    }
    scanLineAnimationing = YES;
    CAAnimationGroup *group = [CAAnimationGroup animation];
    
    CABasicAnimation *basicAni = [CABasicAnimation animationWithKeyPath:@"position.y"];
    basicAni.byValue = @300;
    basicAni.duration = 3;
    
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    animation.values = @[@0.5, @1, @0.5];
    animation.duration = 3;
    
    group.animations = @[basicAni, animation];
    group.duration = 3;
    group.repeatCount = CGFLOAT_MAX;
    
    [self.scanLineView.layer addAnimation:group forKey:@"scan_animation"];
}

- (void)removeScanAnimation {
    scanLineAnimationing = NO;
    [self.scanLineView.layer removeAnimationForKey:@"scan_animation"];
}

- (void)playComplete {
    if (self.mPlayer != nil) {
        [self.mPlayer stop];
    } else {
        NSURL *url = [[NSBundle bundleForClass:[ZLCodeController class]] URLForResource:@"zl_scan.bundle/scan_completed" withExtension:@"mp3"];
        self.mPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    if (self.mPlayer != nil) {
        [self.mPlayer prepareToPlay];
        [self.mPlayer play];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addScanAnimation) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeScanAnimation) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)showImagePicker {
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
        configuration.filter = [PHPickerFilter imagesFilter]; // 可配置查询用户相册中文件的类型，支持三种
        configuration.selectionLimit = 1; // 默认为1，为0时表示可多选。
        
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIImagePickerController *imagePicker = [UIImagePickerController new];
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.delegate = self;
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

BOOL torchOn = NO;
- (void)torchBtnClick:(UIButton *)button {
    torchOn = !torchOn;
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    [device lockForConfiguration:nil];
    if (torchOn) {
        [button setImage:[UIImage imageNamed:@"zl_scan.bundle/torch_off" inBundle:[NSBundle bundleForClass:[ZLCodeController class]] compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
        device.torchMode = AVCaptureTorchModeOn;
    } else {
        [button setImage:[UIImage imageNamed:@"zl_scan.bundle/torch_on" inBundle:[NSBundle bundleForClass:[ZLCodeController class]] compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
        device.torchMode = AVCaptureTorchModeOff;
    }
    [device unlockForConfiguration];
}

- (void)backBtnClick {
    if (self.delegate) {
        [self.delegate ZLCodeControllerBackButtonClick:self];
    }
}

- (void)handleResult:(NSString *)result {
    if (self.delegate) {
        [self.delegate ZLCodeController:self handleScanResult:result];
    }
}

- (BOOL)detectWithBarcode:(cv::Mat *)img {
    std::vector<cv::Point> corners;
    std::vector<std::string> decode_info;
    std::vector<cv::barcode::BarcodeType> decoded_type;
    bool result_detection = barcodeDet->detectAndDecode(*img, decode_info, decoded_type, corners);
    if (result_detection) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self handleResult:[NSString stringWithUTF8String:decode_info[0].c_str()]];
        });
    }
    return result_detection;
}

// cast 计算出的偏差值，小于1.0表示比较正常，大于1.0表示存在亮度异常；
// 当cast异常时，da大于0表示过亮，da小于0表示过暗。
static void detect_brightness(cv::Mat input_img, float& cast, float& da) {
    cv::Mat gray_img;
    cv::cvtColor(input_img, gray_img, cv::COLOR_BGR2GRAY);

    float a = 0, Ma = 0;
    int hist[256] = { 0 };

    for (int i = 0; i < gray_img.rows; i++) {
        for (int j = 0; j < gray_img.cols; j++) {
            a += float(gray_img.at<uchar>(i, j) - 128); // 在计算过程中，考虑128为亮度均值点
            hist[gray_img.at<uchar>(i, j)]++;
        }
    }

    da = a / float(gray_img.total());
  
    for (int i = 0; i < 256; i++) {
        Ma += abs(i - 128 - da) * hist[i];
    }

    Ma /= float(gray_img.total());
    cast = abs(da) / abs(Ma);
}

- (void)processImage:(Mat *)image {
    if (firstStartScanLineAnimation) {
        firstStartScanLineAnimation = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self addScanAnimation];
        });
    }
    cv::Mat *img = (cv::Mat *)image.nativePtr;
    
    if (!torchOn) {
        float cast = 1.0f, da = 0.0f;
        detect_brightness(*img, cast, da);
        if (cast > 1) {
            if (da > 0) {
//                NSLog(@"过亮");
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.torchButton.hidden = YES;
                });
            } else {
//                NSLog(@"过暗%.2f", da);
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.torchButton.hidden = NO;
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.torchButton.hidden = YES;
            });
        }
    }
    
    if ([self detectWithBarcode:img]) {
        [self playComplete];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *snapView = [self.view snapshotViewAfterScreenUpdates:YES];
            [self.view addSubview:snapView];
            [self.view bringSubviewToFront:self.backButton];
        });
        [camera stop];
        return;
    }
    
    std::vector<cv::Mat> vPoints;
    
    std::vector<std::string> strDecoded = detector->detectAndDecode(*img, vPoints);
    double scale = image.width / [UIScreen mainScreen].bounds.size.width;
    if (strDecoded.size() > 0) {
        if (qrScanCount++ > 5) {
            [self playComplete];
            if (strDecoded.size() == 1) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self handleResult:[NSString stringWithUTF8String:strDecoded[0].c_str()]];
                });
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.scanLineView.hidden = YES;
                UIView *snapView = [self.view snapshotViewAfterScreenUpdates:YES];
                [self.codes removeAllObjects];
                if (strDecoded.size() > 1) {
                    for (int i = 0; i < strDecoded.size(); i++) {
//                        std::cout << "decode-" << i + 1 << ": " << strDecoded[i] << std::endl;
                        cv::Point pt1 = cv::Point((int)(vPoints[i].at<float>(0, 0) / scale), (int)(vPoints[i].at<float>(0, 1) / scale));
//                        cv::Point pt2 = cv::Point((int)(vPoints[i].at<float>(1, 0) / scale), (int)(vPoints[i].at<float>(1, 1) / scale));
                        cv::Point pt3 = cv::Point((int)(vPoints[i].at<float>(2, 0) / scale), (int)(vPoints[i].at<float>(2, 1) / scale));
//                    cv::Point pt4 = cv::Point((int)(vPoints[i].at<float>(3, 0) / scale), (int)(vPoints[i].at<float>(3, 1) / scale));
//                    std::cout << "p1:(" << pt1.x << "," << pt1.y << ")\n"
//                                 "p2:(" << pt2.x << "," << pt2.y << ")\n"
//                                 "p3:(" << pt3.x << "," << pt3.y << ")\n"
//                                 "p4:(" << pt4.x << "," << pt4.y << ")\n";
                        CGPoint center = CGPointMake((pt3.x + pt1.x) * 0.5, (pt3.y + pt1.y) * 0.5);
//                        CGSize size = CGSizeMake(pt3.x - pt1.x, pt3.y - pt1.y);
//                        NSLog(@"center:%@,size:%@", [NSValue valueWithCGPoint:center], [NSValue valueWithCGSize:size]);
                        
                        CGFloat WH = 30;
                        CGFloat halfWH = 0.5 * WH;
                        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(center.x - halfWH, center.y - halfWH, WH, WH)];
                        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                        button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
                        button.backgroundColor = [UIColor greenColor];
                        [button setTitle:@"→" forState:UIControlStateNormal];
                        [button addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
                        button.clipsToBounds = YES;
                        button.layer.cornerRadius = halfWH;
                        button.tag = 0x11 + i;
                        if (self.delegate) {
                            [self.delegate ZLCodeController:self configButtonWhenMultiQrResult:button];
                        }
                        [snapView addSubview:button];
                        
                        [self.codes addObject:[NSString stringWithUTF8String:strDecoded[i].c_str()]];
                    }
                }
                
                [self.view addSubview:snapView];
                [self.view bringSubviewToFront:self.backButton];
            });
            [camera stop];
        }
    }
}

- (void)buttonClick:(UIButton *)button {
    button.enabled = NO;
    
    NSString *result = [self.codes objectAtIndex:button.tag - 0x11];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self handleResult:result];
    });
}

#pragma mark - imagepicker delegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    __block UIImage *image = nil;
    if (picker.allowsEditing) {
        image = info[UIImagePickerControllerEditedImage];
    } else {
        image = info[UIImagePickerControllerOriginalImage];
    }
    [self handlePickerImage:image];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    if (results.count != 1) {
        return;
    }
    for (PHPickerResult *result in results) {
      // Get UIImage
      [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
         if ([object isKindOfClass:[UIImage class]]) {
             [self handlePickerImage:(UIImage *)object];
         }
      }];
    }
    
}

- (void)handlePickerImage:(UIImage *)image {
    
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    NSArray<CIFeature *> *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
    if (features == nil || features.count == 0) {
        if (self.delegate) {
            [self.delegate ZLCodeControllerPhotoNotRecognised:self];
        }
        return;
    }
    [self playComplete];
    CIQRCodeFeature *feature = (CIQRCodeFeature *)features.firstObject;
    NSString *code = feature.messageString;
    [self handleResult:code];
}

@end
