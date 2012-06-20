//
//  PCKioskViewController.m
//  Pad CMS
//
//  Created by Oleg Zhitnik on 23.04.12.
//  Copyright (c) 2012 Adyax. All rights reserved.
//

#import "PCKioskViewController.h"
#import "PCKioskSubview.h"

@interface PCKioskViewController (private)
- (void) switchToSubviewWithIndex:(NSInteger) index;
- (PCKioskSubview*) currentSubview;
- (PCKioskSubview*) subviewWithIndex:(NSInteger) index;
- (NSInteger) indexOfSubview:(PCKioskSubview*) subview;
@end

@implementation PCKioskViewController

@synthesize kioskSubviews = _kioskSubviews;
@synthesize subviewsFactory = _subviewsFactory;
@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize downloadInProgress = _downloadInProgress;
@synthesize downloadingRevisionIndex = _downloadingRevisionIndex;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (id) initWithKioskSubviewsFactory:(PCKioskAbstractSubviewsFactory*) factory andFrame:(CGRect) frame andDataSource:(id<PCKioskDataSourceProtocol>) dsource
{
    _initialFrame = frame;
    self.subviewsFactory = factory;
    self.dataSource = dsource;
    
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.subviewsFactory = nil;
    self.kioskSubviews = nil;
    _dataSource = nil;
    _delegate = nil;
    [super dealloc];
}

#pragma mark - View lifecycle


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    self.view = [[[UIView alloc] initWithFrame:_initialFrame] autorelease];
    self.view.backgroundColor = [UIColor blackColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;
    
    self.kioskSubviews = [self.subviewsFactory subviewsListWithFrame:self.view.bounds];
    _currentSubviewIndex = 0;
    
    for(PCKioskSubview *current in self.kioskSubviews)
    {
        [self.view addSubview:current];
        current.delegate = self;
        current.dataSource = self.dataSource;
        [current createView];
    }
    
    PCKioskSubview      *firstSubview = [self subviewWithIndex:_currentSubviewIndex];
    firstSubview.hidden = NO;
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange)
                                                 name:@"UIDeviceOrientationDidChangeNotification"
                                               object:nil];
}


/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
*/

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self reloadSubviews];
    
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

-(void)deviceOrientationDidChange
{
    if(self.kioskSubviews)
    {
        for (PCKioskSubview *current in self.kioskSubviews)
        {
            if(current)
            {
                [current deviceOrientationDidChange];
            }
        }
    }
}

- (void) reloadSubviews
{
    if(self.kioskSubviews)
    {
        for (PCKioskSubview *current in self.kioskSubviews)
        {
            if(current)
            {
                [current reloadRevisions];
            }
        }
    }
}

- (void) updateRevisionWithIndex:(NSInteger)index
{
    if(self.kioskSubviews)
    {
        for (PCKioskSubview *current in self.kioskSubviews)
        {
            if(current)
            {
                [current updateRevisionWithIndex:index];
            }
        }
    }
}

#pragma mark - Downloading flow

- (void) downloadStartedWithRevisionIndex:(NSInteger)index
{
    self.downloadInProgress = TRUE;
    self.downloadingRevisionIndex = index;

    // inform single-control subviews for select element
    for(PCKioskSubview *subview in self.kioskSubviews)
    {
        [subview selectRevisionWithIndex:index];
    }
    
    // inform all subviews about download starting
    for(PCKioskSubview *subview in self.kioskSubviews)
    {
        [subview downloadStartedWithRevisionIndex:index];
    }
}

- (void) downloadFinishedWithRevisionIndex:(NSInteger)index
{
    self.downloadInProgress = FALSE;
    for(PCKioskSubview *subview in self.kioskSubviews)
    {
        [subview downloadFinishedWithRevisionIndex:index];
    }
}

- (void) downloadFailedWithRevisionIndex:(NSInteger)index
{
    self.downloadInProgress = FALSE;
    for(PCKioskSubview *subview in self.kioskSubviews)
    {
        [subview downloadFailedWithRevisionIndex:index];
    }
}

- (void) downloadCanceledWithRevisionIndex:(NSInteger)index
{
    self.downloadInProgress = FALSE;
    for(PCKioskSubview *subview in self.kioskSubviews)
    {
        [subview downloadCanceledWithRevisionIndex:index];
    }
}

- (void) downloadingProgressChangedWithRevisionIndex:(NSInteger)index andProgess:(float) progress
{
    for(PCKioskSubview *subview in self.kioskSubviews)
    {
        [subview downloadProgressUpdatedWithRevisionIndex:index
                                              andProgress:progress
                                         andRemainingTime:nil];
    }
}

#pragma mark - PCKioskSubviewDelegateProtocol

- (void) downloadButtonTappedWithRevisionIndex:(NSInteger) index
{
    [self.delegate downloadRevisionWithIndex:index];
}

- (void) readButtonTappedWithRevisionIndex:(NSInteger) index
{
    [self.delegate readRevisionWithIndex:index];
}

- (void) cancelButtonTappedWithRevisionIndex:(NSInteger) index
{
    [self.delegate cancelDownloadingRevisionWithIndex:index];
}

- (void) deleteButtonTappedWithRevisionIndex:(NSInteger) index
{
    [self.delegate deleteRevisionDataWithIndex:index];
    [self reloadSubviews];
}

- (void) updateButtonTappedWithRevisionIndex:(NSInteger) index
{
    [self.delegate updateRevisionWithIndex:index];
    [self reloadSubviews];
}

- (void) purchaseButtonTappedWithRevisionIndex:(NSInteger) index
{
    [self.delegate purchaseRevisionWithIndex:index];
}

#pragma mark - Kiosk Subviews Navigation

- (void) switchToNextSubview
{
    if(!self.kioskSubviews) return;
    if([self.kioskSubviews count]<=1) return; // nothing to switch
    
    NSInteger       newIndex = _currentSubviewIndex + 1;
    
    if(newIndex >= [self.kioskSubviews count])
    {
        newIndex = 0;
    }
    
    [self switchToSubviewWithIndex:newIndex];
}

- (void) switchToPreviousSubview
{
    if(!self.kioskSubviews) return;
    if([self.kioskSubviews count]<=1) return; // nothing to switch
    
    NSInteger       newIndex = _currentSubviewIndex - 1;
    
    if(newIndex < 0)
    {
        newIndex = [self.kioskSubviews count] - 1;
    }
    
    [self switchToSubviewWithIndex:newIndex];
}

- (BOOL) switchToSubviewWithTag:(NSInteger) tag
{
    if(self.kioskSubviews)
    {
        for (PCKioskSubview *current in self.kioskSubviews)
        {
            if(current)
            {
                if(current.tag==tag)
                {
                    NSInteger      destinationIndex = [self indexOfSubview:current];

                    if(destinationIndex >= 0)
                    {
                        [self switchToSubviewWithIndex:destinationIndex];
                        return TRUE;
                    }
                }
            }
        }
    }
    return FALSE;
}

- (NSInteger) currentSubviewTag
{
    if(self.kioskSubviews)
    {
        PCKioskSubview      *current = [self currentSubview];
        
        return current.tag;
    }
    return -1;
}

#pragma mark - Private

- (void) switchToSubviewWithIndex:(NSInteger) index
{
    if(_currentSubviewIndex != index)
    {
        PCKioskSubview      *oldSubview = [self subviewWithIndex:_currentSubviewIndex];
        PCKioskSubview      *newSubview = [self subviewWithIndex:index];
        
        // hide old subview
        if(oldSubview)
        {
            [oldSubview setHidden:YES];
        }
        
        if(newSubview)
        {
            [newSubview setHidden:NO];
            _currentSubviewIndex = index;
        }
    }
}

- (PCKioskSubview*) currentSubview
{
    return [self subviewWithIndex:_currentSubviewIndex];
}

- (PCKioskSubview*) subviewWithIndex:(NSInteger) index
{
    if(self.kioskSubviews)
    {
        if(index>=0 && index<[self.kioskSubviews count])
        {
            return [self.kioskSubviews objectAtIndex:index];
        }
    }
    return nil;
}

- (NSInteger) indexOfSubview:(PCKioskSubview*) subview
{
    if(subview)
    {
        if(self.kioskSubviews)
        {
            for (int i=0; i<[self.kioskSubviews count]; i++)
            {
                PCKioskSubview      *current = [self.kioskSubviews objectAtIndex:i];
                
                if(current)
                {
                    if(current==subview)
                    {
                        return i;
                    }
                }
            }
        }
    }
    return -1;
}

@end
