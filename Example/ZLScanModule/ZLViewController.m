//
//  ZLViewController.m
//  ZLScanModule
//
//  Created by richiezhl on 02/18/2022.
//  Copyright (c) 2022 richiezhl. All rights reserved.
//

#import "ZLViewController.h"
#import <ZLScanModule/ZLCodeController.h>

@interface ZLViewController ()  <ZLCodeControllerDelegate>

@end

@implementation ZLViewController

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    ZLCodeController *controller = [[ZLCodeController alloc] init];
    controller.delegate = self;
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)ZLCodeControllerHandleCamaraDenied:(ZLCodeController *)controller {
    
}

- (void)ZLCodeControllerHandleCamaraNotSupported:(ZLCodeController *)controller {
    
}

- (void)ZLCodeControllerPhotoNotRecognised:(ZLCodeController *)controller {
    NSLog(@"%s", __FUNCTION__);
}

- (void)ZLCodeControllerBackButtonClick:(ZLCodeController *)controller {
    [controller.navigationController popViewControllerAnimated:YES];
}

- (void)ZLCodeController:(ZLCodeController *)controller handleScanResult:(NSString *)code {
    NSLog(@"scan result:%@", code);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller.navigationController popViewControllerAnimated:YES];
    });
}

- (void)ZLCodeController:(ZLCodeController *)controller configBackButton:(UIButton *)backButton {

}

- (void)ZLCodeController:(ZLCodeController *)controller configButtonWhenMultiQrResult:(nonnull UIButton *)button {
    
}

@end
