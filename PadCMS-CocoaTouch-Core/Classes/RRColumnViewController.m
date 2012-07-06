//
//  RRColumnViewController.m
//  PadCMS-CocoaTouch-Core
//
//  Created by Maxim Pervushin on 7/6/12.
//  Copyright (c) 2012 Adyax. All rights reserved.
//

#import "RRColumnViewController.h"

@implementation RRColumnViewController
@synthesize pageSize = _pageSize;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (CGSize)pageSizeForViewController:(PCPageViewController *)pageViewController
{
    return self.pageSize;
}

@end
