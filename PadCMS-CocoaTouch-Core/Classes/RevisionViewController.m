//
//  RevisionViewController.m
//  PadCMS-CocoaTouch-Core
//
//  Created by Alexey Petrosyan on 7/4/12.
//  Copyright (c) 2012 Adyax. All rights reserved.
//

#import "RevisionViewController.h"
#import "PCMagazineViewControllersFactory.h"
#import "PCPageViewController.h"
#import "RRColumnViewController.h"

NSUInteger UIViewAutoresizingAll = UIViewAutoresizingFlexibleLeftMargin | 
UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin | 
UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight | 
UIViewAutoresizingFlexibleBottomMargin;


@interface RevisionViewController ()
{
    RRComplexScrollView *_mainScrollView;
    RRColumnViewController *_columnViewController;
}

@end

@implementation RevisionViewController
@synthesize revision = _revision;

- (id)initWithRevision:(PCRevision *)revision
{
	self = [super init];
    
    if (self) {
        _revision = [revision retain];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _columnViewController = [[RRColumnViewController alloc] init];
    _columnViewController.pageSize = CGSizeMake(self.view.bounds.size.width, 
                                                self.view.bounds.size.height);
    
    _mainScrollView = [[RRComplexScrollView alloc] initWithFrame:self.view.bounds];
    _mainScrollView.autoresizingMask = UIViewAutoresizingAll;
    _mainScrollView.dataSource = self;
    [self.view addSubview:_mainScrollView];
    [_mainScrollView reloadData];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] 
                                                    initWithTarget:self action:@selector(twinDoubleTap:)];
    tapGestureRecognizer.numberOfTapsRequired = 2;
    tapGestureRecognizer.numberOfTouchesRequired = 2;
    [self.view addGestureRecognizer:tapGestureRecognizer];
    [tapGestureRecognizer release];
}

- (void)twinDoubleTap:(UITapGestureRecognizer *)recognizer
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewDidUnload
{	
    [super viewDidUnload];

    [_mainScrollView removeFromSuperview];
    [_mainScrollView release];
    
    [_columnViewController release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (self.revision.horizontalOrientation)
    {
        return UIInterfaceOrientationIsLandscape(interfaceOrientation);
    }
    
    if (self.revision.horizontalMode && self.revision.horizontalPages.count != 0)
    {
        return YES;
    }
    
    return interfaceOrientation == UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

#pragma mark - RRComplexScrollViewDatasource

- (PCPageViewController *)pageControllerForPageController:(PCPageViewController *)pageController 
                                               connection:(RRPageConnection)connection 
                                               scrollView:(RRComplexScrollView *)scrollView
{
    PCPage *nextPage = nil;
    
    switch (connection) {
        case RRPageConnectionInvalid:
            nextPage = self.revision.coverPage;
            break;
            
        case RRPageConnectionLeft:
            nextPage = pageController.page.leftPage;
            break;
            
        case RRPageConnectionRight:
            nextPage = pageController.page.rightPage;
            break;
            
        case RRPageConnectionTop:
            nextPage = pageController.page.topPage;
            break;
            
        case RRPageConnectionBottom:
            nextPage = pageController.page.bottomPage;
            break;
            
        case RRPageConnectionRotation:
            
            break;
            
        default:
            break;
    }
    
    if (nextPage != nil) {
        PCPageViewController *nextPageController = [[PCMagazineViewControllersFactory factory] viewControllerForPage:nextPage];
        
        nextPageController.columnViewController = (PCColumnViewController *)_columnViewController;
        
        if (nextPageController.view) { // allways YES. Used to load view
            [nextPageController loadFullView];
        }
        
        return nextPageController;
    }
    
    return nil;
}

@end
