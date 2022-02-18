//
//  ZLCodeController.h
//  OpenCVDemo
//
//  Created by lylaut on 2022/2/17.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ZLCodeController;
@protocol ZLCodeControllerDelegate <NSObject>

- (void)ZLCodeControllerHandleCamaraDenied:(ZLCodeController *)controller;

- (void)ZLCodeControllerHandleCamaraNotSupported:(ZLCodeController *)controller;

- (void)ZLCodeControllerPhotoNotRecognised:(ZLCodeController *)controller;

- (void)ZLCodeControllerBackButtonClick:(ZLCodeController *)controller;

- (void)ZLCodeController:(ZLCodeController *)controller handleScanResult:(NSString *)code;

- (void)ZLCodeController:(ZLCodeController *)controller configBackButton:(UIButton *)backButton;

- (void)ZLCodeController:(ZLCodeController *)controller configButtonWhenMultiQrResult:(UIButton *)button;

@end

@interface ZLCodeController : UIViewController

@property (nonatomic, weak) id<ZLCodeControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
