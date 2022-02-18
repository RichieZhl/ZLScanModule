//
//  NavigationController.m
//  ZLScanModule_Example
//
//  Created by lylaut on 2022/2/18.
//  Copyright © 2022 richiezhl. All rights reserved.
//

#import "NavigationController.h"

@interface NavigationController ()

@end

@implementation NavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (BOOL)shouldAutorotate {
    if (self.topViewController) {
        return self.topViewController.shouldAutorotate;
    }
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (self.topViewController) {
        return self.topViewController.supportedInterfaceOrientations;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
