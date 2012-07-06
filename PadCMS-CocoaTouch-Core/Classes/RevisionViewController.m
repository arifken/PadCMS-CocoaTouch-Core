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
    _mainScrollView.dataSource = self;
    [self.view addSubview:_mainScrollView];
    [_mainScrollView reloadData];
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
	return YES;
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
        
        nextPageController.columnViewController = _columnViewController;
        
        if (nextPageController.view) { // allways YES. Used to load view
            [nextPageController loadFullView];
        }
        
        return nextPageController;
    }
    
    return nil;
}

@end
