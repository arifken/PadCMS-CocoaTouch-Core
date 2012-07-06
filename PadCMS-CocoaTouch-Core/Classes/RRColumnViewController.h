//
//  RRColumnViewController.h
//  PadCMS-CocoaTouch-Core
//
//  Created by Maxim Pervushin on 7/6/12.
//  Copyright (c) 2012 Adyax. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PCPageViewController;

/**
 @class RRColumnViewController
 @brief PCColumnViewController simulator 
 */
@interface RRColumnViewController : UIViewController

@property (assign, nonatomic) CGSize pageSize;

- (CGSize)pageSizeForViewController:(PCPageViewController *)pageViewController;

@end
