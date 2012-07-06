//
//  StoreController.m
//  Pad CMS
//
//  Created by Alexey Igoshev on 6/20/12.
//  Copyright (c) PadCMS (http://www.padcms.net)
//
//
//  This software is governed by the CeCILL-C  license under French law and
//  abiding by the rules of distribution of free software.  You can  use,
//  modify and/ or redistribute the software under the terms of the CeCILL-C
//  license as circulated by CEA, CNRS and INRIA at the following URL
//  "http://www.cecill.info".
//  
//  As a counterpart to the access to the source code and  rights to copy,
//  modify and redistribute granted by the license, users are provided only
//  with a limited warranty  and the software's author,  the holder of the
//  economic rights,  and the successive licensors  have only  limited
//  liability.
//  
//  In this respect, the user's attention is drawn to the risks associated
//  with loading,  using,  modifying and/or developing or reproducing the
//  software by the user in light of its specific status of free software,
//  that may mean  that it is complicated to manipulate,  and  that  also
//  therefore means  that it is reserved for developers  and  experienced
//  professionals having in-depth computer knowledge. Users are therefore
//  encouraged to load and test the software's suitability as regards their
//  requirements in conditions enabling the security of their systems and/or
//  data to be ensured and,  more generally, to use and operate it in the
//  same conditions as regards security.
//  
//  The fact that you are presently reading this means that you have had
//  knowledge of the CeCILL-C license and that you accept its terms.
//


#import "PCStoreController.h"
#import "PCConfig.h"
#import "JSON.h"
#import "AFJSONRequestOperation.h"
#import "Helper.h"
#import "PCApplication.h"
#import "PCPathHelper.h"
#import "PCStoreControllerDelegate.h"
#import "PCRevision.h"
#import "PCIssue.h"
#import "PCDownloadManager.h"
#import "PCResourceCache.h"
#import "PCDownloadApiClient.h"
#import "PCRevisionViewController.h"
#import "InAppPurchases.h"
#import "RevisionViewController.h"

NSString* PCNetworkServiceJSONRPCPath = @"/api/v1/jsonrpc.php";


@interface PCStoreController()
@property (nonatomic, readwrite, retain) PCApplication* application;
@property (nonatomic, retain) PCRevisionViewController* revisionViewController;


//---TEST----
@property (nonatomic, retain) RevisionViewController* revisionController;
@end

@implementation PCStoreController
@synthesize rootViewController=_rootViewController;
//@synthesize navigationController=_navigationController;
@synthesize application=_application;
@synthesize revisionViewController=_revisionViewController;
@synthesize revisionController=_revisionController;

- (id)initWithStoreRootViewController:(UIViewController<PCStoreControllerDelegate>*)viewController
{
  
  self = [super init];
  if (self)
  {
    _rootViewController = [viewController retain];
    [_rootViewController setStoreController:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendReceipt:) name:kInAppPurchaseManagerTransactionSucceededNotification object:nil];
    [self launch];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  }
  return nil;
}

-(void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  //[_navigationController release], _navigationController = nil;
  [_rootViewController release], _rootViewController = nil;
  [_application release], _application = nil;
  [_revisionViewController release], _revisionViewController = nil;
  [_revisionController release], _revisionController = nil;
  [super dealloc];
}

/*-(UINavigationController *)navigationController
{
  if (_navigationController)
  {
    _navigationController = [[UINavigationController alloc] initWithRootViewController:_rootViewController];
  }
  return _navigationController;
}*/

-(void)launch
{
  [UIApplication sharedApplication].applicationIconBadgeNumber = -1;
  [self downloadIssueList];
  
}

-(void)downloadIssueList
{
  [self showActivity];
  NSString *devId = [[UIDevice currentDevice]uniqueIdentifier];
	NSURL* theURL = [[PCConfig serverURL] URLByAppendingPathComponent:PCNetworkServiceJSONRPCPath];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:5.0];
	[request setHTTPMethod:@"POST"];
	NSMutableDictionary *mainDict = [NSMutableDictionary dictionary];
	[mainDict setObject:@"client.getIssues" forKey:@"method"];
	
	NSDictionary *innerDict = [NSDictionary dictionaryWithObjectsAndKeys:devId, @"sUdid",[NSString stringWithFormat:@"%d",[PCConfig clientIdentifier]], @"iClientId",[NSString stringWithFormat:@"%d",[PCConfig applicationIdentifier]],@"iApplicationId", nil];
	[mainDict setObject:innerDict forKey:@"params"];
	[mainDict setObject:@"1" forKey:@"id"];
	SBJsonWriter *tmpJsonWriter = [[SBJsonWriter alloc] init];
	NSString *jsonString = [tmpJsonWriter stringWithObject:mainDict];
	[tmpJsonWriter release];
	[request setHTTPBody:[jsonString dataUsingEncoding:NSASCIIStringEncoding]];
  
  AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
    SBJsonWriter *tmpJsonWriter = [[SBJsonWriter alloc] init];
    NSString *temp = [tmpJsonWriter stringWithObject:JSON];
    [tmpJsonWriter release];
    NSString* stringWithoutNull = [temp stringByReplacingOccurrencesOfString:@"null" withString:@"\"\""];
		NSDictionary* theDict = [stringWithoutNull JSONValue];
    [[theDict objectForKey:@"result"] writeToFile:[[Helper getHomeDirectory] stringByAppendingPathComponent:@"server.plist"] atomically:YES];
    [self loadApplicationFromPlist];
  } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
      [self showAlertWithTitle:@"You must be connected to the Internet."];
      [self loadApplicationFromPlist];
  }];
  operation.successCallbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  operation.failureCallbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  [operation start];
}

-(void)loadApplicationFromPlist
{
  NSString *plistPath = [[PCPathHelper pathForPrivateDocuments] stringByAppendingPathComponent:@"server.plist"];
  NSDictionary *plistContent = [NSDictionary dictionaryWithContentsOfFile:plistPath];
  if(plistContent == nil)
  {
      [self showAlertWithTitle:@"The list of available magazines could not be downloaded"];
  }
  else if([plistContent count]==0)
  {
    [self showAlertWithTitle:@"The list of available magazines could not be downloaded"];
  }
  else {
      NSDictionary *applicationsList = [plistContent objectForKey:PCJSONApplicationsKey];
      NSArray *keys = [applicationsList allKeys];
      
      if ([keys count] > 0)
      {
        NSDictionary *applicationParameters = [applicationsList objectForKey:[keys objectAtIndex:0]];
        
        self.application = [[[PCApplication alloc] initWithParameters:applicationParameters
                                                         rootDirectory:[PCPathHelper pathForPrivateDocuments]] autorelease];
      } else 
      {
        [self showAlertWithTitle:@"The list of available magazines could not be downloaded"];
      }
    }
  [self hideActivity];
  if (!self.application) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.rootViewController displayIssues];
  });

  

}

-(void)showActivity
{
  if ([self.rootViewController respondsToSelector:@selector(showActivityIndicator)])
  {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.rootViewController showActivityIndicator];
    });
  }
}

-(void)hideActivity
{
  if ([self.rootViewController respondsToSelector:@selector(hideActivityIndicator)])
  {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.rootViewController hideActivityIndicator];
    });
    
  }
}

-(void)showAlertWithTitle:(NSString*)title
{
  dispatch_async(dispatch_get_main_queue(), ^{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    [alert release];
  });

}

- (PCRevision*) revisionWithIndex:(NSInteger)index
{
  NSMutableArray *allRevisions = [[[NSMutableArray alloc] init] autorelease];
  
  NSArray *issues = self.application.issues;
  for (PCIssue *issue in issues)
  {
    [allRevisions addObjectsFromArray:issue.revisions];
  }
  
  if (index>=0 && index<[allRevisions count])
  {
    PCRevision *revision = [allRevisions objectAtIndex:index];
    return revision;
  }
  
  return nil;
}

- (PCRevision*) revisionWithIdentifier:(NSInteger)identifier
{
  NSMutableArray *allRevisions = [[[NSMutableArray alloc] init] autorelease];
  
  NSArray *issues = self.application.issues;
  for (PCIssue *issue in issues)
  {
    [allRevisions addObjectsFromArray:issue.revisions];
  }
  
  for(PCRevision *currentRevision in allRevisions)
  {
    if(currentRevision.identifier == identifier) return currentRevision;
  }
  
  return nil;
}



#pragma mark - PCKioskDataSourceProtocol


- (NSInteger)numberOfRevisions
{
  NSInteger revisionsCount = 0;
  
  NSArray *issues = self.application.issues;
  for (PCIssue *issue in issues)
  {
    revisionsCount += [issue.revisions count];
  }
  
  return revisionsCount;
}

- (NSString *)issueTitleWithIndex:(NSInteger)index
{
  PCRevision *revision = [self revisionWithIndex:index];
  
  if (revision != nil && revision.issue != nil)
  {
    return revision.issue.title;
  }
  
  return @"";
}

- (NSString *)revisionTitleWithIndex:(NSInteger)index
{
  PCRevision *revision = [self revisionWithIndex:index];
  
  if (revision != nil)
  {
    return revision.title;
  }
  
  return @"";
}

- (NSString *)revisionStateWithIndex:(NSInteger)index
{
  return @"";
}

- (BOOL)isRevisionDownloadedWithIndex:(NSInteger)index
{
  PCRevision *revision = [self revisionWithIndex:index];
  
  if (revision)
  {
    return  [revision isDownloaded];
  }
  
  return NO;
}

- (UIImage *)revisionCoverImageWithIndex:(NSInteger)index andDelegate:(id<PCKioskCoverImageProcessingProtocol>)delegate
{
  PCRevision *revision = [self revisionWithIndex:index];
  
  if (revision)
  {
    return  revision.coverImage;
  }
  
  return nil;
}

-(BOOL)isRevisionPaidWithIndex:(NSInteger)index
{
	PCRevision *revision = [self revisionWithIndex:index];
  
  if (revision.issue)
  {
    return  revision.issue.paid;
  }
  
  return NO;
}


-(NSString *)priceWithIndex:(NSInteger)index
{
	PCRevision *revision = [self revisionWithIndex:index];
  return revision.issue.price;					
}

-(NSString *)productIdentifierWithIndex:(NSInteger)index
{
	PCRevision *revision = [self revisionWithIndex:index];
  return revision.issue.productIdentifier;
}


#pragma mark - PCKioskViewControllerDelegateProtocol

- (void) readRevisionWithIndex:(NSInteger)index
{
  PCRevision *currentRevision = [self revisionWithIndex:index];
  
  if (currentRevision != nil)
  {
    [self rotateInterfaceIfNeedWithRevision:currentRevision];
    
    [PCDownloadManager sharedManager].revision = currentRevision;
    [[PCDownloadManager sharedManager] startDownloading];
    
    RevisionViewController *revisionViewController = [[RevisionViewController alloc] initWithRevision:currentRevision];
    [self.rootViewController.navigationController pushViewController:revisionViewController animated:YES];
    [revisionViewController release];
    
//    if (_revisionController == nil)
//    {
//            
//      _revisionController = [[RevisionViewController alloc] initWithRevision:currentRevision];
//      [self.rootViewController.navigationController pushViewController:_revisionController animated:NO];
//      [_revisionController release];
//      _revisionController = nil;
//    }
    
 /*   if (_revisionViewController == nil)
    {
      NSBundle *bundle = [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"PadCMS-CocoaTouch-Core-Resources" withExtension:@"bundle"]];
      
      _revisionViewController = [[PCRevisionViewController alloc] 
                                 initWithNibName:@"PCRevisionViewController"
                                 bundle:bundle];
      
      [_revisionViewController setRevision:currentRevision];
      _revisionViewController.mainViewController = self;
      _revisionViewController.initialPageIndex = 0;
   //   [self.rootViewController.view addSubview:_revisionViewController.view];
		[self.rootViewController.navigationController pushViewController:_revisionViewController animated:NO];
     
      
      
    }*/
  }
}

- (void) deleteRevisionDataWithIndex:(NSInteger)index
{
  PCRevision *revision = [self revisionWithIndex:index];
  
  NSString    *message = [NSString stringWithFormat:@"Etes-vous certain de vouloir supprimer ce numéro ? (%@)", revision.issue.title];
  
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                  message:message
                                                 delegate:self
                                        cancelButtonTitle:@"Annuler"
                                        otherButtonTitles:@"Oui", nil];
	alert.delegate = self;
  alert.tag = index;
	[alert show];
	[alert release];
}

- (void) downloadRevisionWithIndex:(NSInteger)index
{
  PCRevision *revision = [self revisionWithIndex:index];
  
  if(revision)
  {
		
		AFNetworkReachabilityStatus remoteHostStatus = [PCDownloadApiClient sharedClient].networkReachabilityStatus;
    if(remoteHostStatus == AFNetworkReachabilityStatusNotReachable) 
		{
			UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Vous devez être connecté à Internet." message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert show];
			[alert release];
			return;
			
		}
    [self.rootViewController downloadStartedWithRevisionIndex:index];
    [self performSelectorInBackground:@selector(doDownloadRevisionWithIndex:) withObject:[NSNumber numberWithInteger:index]];
  }
}

- (void) cancelDownloadingRevisionWithIndex:(NSInteger)index
{
  PCRevision *revision = [self revisionWithIndex:index];
  
  if(revision)
  {
    [revision cancelDownloading];
  }
}

-(void) purchaseRevisionWithIndex:(NSInteger)index
{
	PCRevision *revision = [self revisionWithIndex:index];
	if (revision)
	{
		NSLog(@"doPay");
		
		NSLog(@"productId: %@", revision.issue.productIdentifier);
    
		if([[InAppPurchases sharedInstance] canMakePurchases])
		{
			
			[[InAppPurchases sharedInstance] purchaseForProductId:revision.issue.productIdentifier];
			
		}
		else
		{
			UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Vous ne pouvez procéder à l'achat" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert show];
			[alert release];
		}
    
	}
	
}


- (void) updateRevisionWithIndex:(NSInteger) index
{
}

#pragma mark - Download flow

- (void)doDownloadRevisionWithIndex:(NSNumber *)index
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  PCRevision          *revision = [self revisionWithIndex:[index integerValue]];
  
  if(revision)
  {
    [revision download:^{
      [self performSelectorOnMainThread:@selector(downloadRevisionFinishedWithIndex:)
                             withObject:index
                          waitUntilDone:NO];
    } failed:^(NSError *error) {
      [self performSelectorOnMainThread:@selector(downloadRevisionFailedWithIndex:)
                             withObject:index
                          waitUntilDone:NO];
    } canceled:^{
      [self performSelectorOnMainThread:@selector(downloadRevisionCanceledWithIndex:)
                             withObject:index
                          waitUntilDone:NO];
    } progress:^(float progress) {
      NSDictionary        *info = [NSDictionary dictionaryWithObjectsAndKeys:index, @"index", [NSNumber numberWithFloat:progress], @"progress", nil];
      
      [self performSelectorOnMainThread:@selector(downloadingRevisionProgressUpdate:)
                             withObject:info
                          waitUntilDone:NO];
    }];
  }
  
  
  [pool release];
}

- (void)downloadRevisionCanceledWithIndex:(NSNumber*)index
{
  [self.rootViewController downloadCanceledWithRevisionIndex:[index integerValue]];
  
  PCRevision      *revision = [self revisionWithIndex:[index integerValue]];
  if(revision)
  {
    [revision deleteContent];
    [self.rootViewController updateRevisionWithIndex:[index integerValue]];
  }
}

- (void)downloadRevisionFinishedWithIndex:(NSNumber*)index
{
  [self.rootViewController downloadFinishedWithRevisionIndex:[index integerValue]];
  
}

- (void)downloadRevisionFailedWithIndex:(NSNumber*)index
{
  [self.rootViewController downloadFailedWithRevisionIndex:[index integerValue]];
  
  UIAlertView *errorAllert = [[UIAlertView alloc] 
                              initWithTitle:NSLocalizedString(@"Error downloading issue!", nil) 
                              message:NSLocalizedString(@"Try again later", nil) 
                              delegate:nil
                              cancelButtonTitle:@"OK" 
                              otherButtonTitles:nil];
  
  [errorAllert show];
  [errorAllert release];
  
  PCRevision      *revision = [self revisionWithIndex:[index integerValue]];
  if(revision)
  {
    [revision deleteContent];
    [self.rootViewController updateRevisionWithIndex:[index integerValue]];
  }
}

- (void)downloadingRevisionProgressUpdate:(NSDictionary*)info
{
  NSNumber        *index = [info objectForKey:@"index"];
  NSNumber        *progress = [info objectForKey:@"progress"];
  
  [self.rootViewController downloadingProgressChangedWithRevisionIndex:[index integerValue]
                                                             andProgess:[progress floatValue]];
}



#pragma mark - UIAlertViewDelegate
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if(buttonIndex==1)
	{
    NSInteger       index = alertView.tag;
    PCRevision *revision = [self revisionWithIndex:index];
    
    if(revision)
    {
      PCDownloadManager* manager = [PCDownloadManager sharedManager];
      if (manager.revision == revision)
      {
        [manager cancelAllOperations];
      }
      
      if (revision)
      {
        [[PCResourceCache sharedInstance] removeAllObjects];
        [revision deleteContent];
        [self.rootViewController updateRevisionWithIndex:index];
      }
    }
	}
}

#pragma mark - misc

- (void)rotateInterfaceIfNeedWithRevision:(PCRevision*) revision
{
  if(revision.horizontalOrientation)
  {
    UIInterfaceOrientation curOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    // if we enter in view controller in portrait with revision with horizontal orientation
    if(UIDeviceOrientationIsPortrait(curOrientation))
    {
      [UIView beginAnimations:@"View Flip" context:nil];
      [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
      [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
      [UIView setAnimationDelegate:self];
      
      self.rootViewController.view.frame = CGRectMake(0.0, 0.0, 1024, 768);
      self.rootViewController.view.center = CGPointMake(512, 384);
      [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeLeft];
      CGAffineTransform landscapeTransform = CGAffineTransformMakeRotation( 90.0 * M_PI / -180.0 );
      landscapeTransform = CGAffineTransformTranslate( landscapeTransform, -128.0, -128.0 );
      self.rootViewController.view.transform = landscapeTransform;
      
      [UIView commitAnimations];
    }
  } 
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
  if([animationID isEqualToString:@"View Flip"])
  {
    [self.rootViewController deviceOrientationDidChange];
  }
}

- (void) switchToKiosk
{
  [[NSURLCache sharedURLCache] removeAllCachedResponses];
  [[PCResourceCache sharedInstance] removeAllObjects];
  [[PCDownloadManager sharedManager] cancelAllOperations];
 // [_revisionViewController.view removeFromSuperview];
	[self.rootViewController.navigationController popToRootViewControllerAnimated:NO];
  self.revisionViewController = nil;
  
}

- (void) searchWithKeyphrase:(NSString*) keyphrase
{
  PCSearchViewController* searchViewController = [[PCSearchViewController alloc] initWithNibName:@"PCSearchViewController" bundle:nil];
  searchViewController.searchKeyphrase = keyphrase;
  searchViewController.application = self.application;
  searchViewController.delegate = self;
  
  [self.rootViewController presentViewController:searchViewController animated:YES completion:nil];
 
  [searchViewController release];
}

-(void)subscribe
{
	[[InAppPurchases sharedInstance] subscribe];
}

#pragma mark - PCSearchViewControllerDelegate

- (void) showRevisionWithIdentifier:(NSInteger) revisionIdentifier andPageIndex:(NSInteger) pageIndex
{
  PCRevision *currentRevision = [self revisionWithIdentifier:revisionIdentifier];
  
  if (currentRevision)
  {
    [self rotateInterfaceIfNeedWithRevision:currentRevision];
    
    [PCDownloadManager sharedManager].revision = currentRevision;
    [[PCDownloadManager sharedManager] startDownloading];
    
    if (_revisionViewController == nil)
    {
      _revisionViewController = [[PCRevisionViewController alloc] 
                                 initWithNibName:@"PCRevisionViewController"
                                 bundle:nil];
      
      [_revisionViewController setRevision:currentRevision];
      _revisionViewController.mainViewController = self;
      _revisionViewController.initialPageIndex = pageIndex;
      [self.rootViewController.view addSubview:_revisionViewController.view];
      
    }
  }
}

/*
- (void) productDataRecieved:(NSNotification *) notification
{
	NSLog(@"From VersionManager::productDataRecieved: %@ %@", [(NSDictionary *)[notification object] objectForKey:@"productIdentifier"], [(NSDictionary *)[notification object] objectForKey:@"localizedPrice"]);
	for(int i = 0; i < [self.items count]; ++i)
	{
		NSDictionary *item = [self.items objectAtIndex:i];
		
		if([[(NSDictionary *)[notification object] objectForKey:@"productIdentifier"] isEqualToString:[item objectForKey:@"issue_product_id"]])
		{
			[item setValue:[NSString stringWithString:[(NSDictionary *)[notification object] objectForKey:@"localizedPrice"]] forKey:@"price"];
			return;
		}
	}
}*/

-(void)restartApplication
{
	[self downloadIssueList];	
}


- (void) sendReceipt: (NSNotification *)notification
{
	NSLog(@"transactionReceipt: %@", [notification object]);
	
	NSString *devId = [[UIDevice currentDevice] uniqueIdentifier];
	
	NSURL* theURL = [[PCConfig serverURL] URLByAppendingPathComponent:PCNetworkServiceJSONRPCPath];
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
	
	[request setHTTPMethod:@"POST"];
	
	NSMutableDictionary *mainDict = [NSMutableDictionary dictionary];
	[mainDict setObject:@"purchase.apple.verifyReceipt" forKey:@"method"];
  
  NSDictionary *innerDict = [NSDictionary dictionaryWithObjectsAndKeys:devId, @"sUdid", [notification object], @"sReceiptData", nil];
	
  
	
	[mainDict setObject:innerDict forKey:@"params"];
	
	[mainDict setObject:@"1" forKey:@"id"];
	
	SBJsonWriter *tmpJsonWriter = [[SBJsonWriter alloc] init];
	NSString *jsonString = [tmpJsonWriter stringWithObject:mainDict];
	
  //	NSLog(@"jsonString is:\n %@", jsonString);
	
	[tmpJsonWriter release];
	
	[request setHTTPBody:[jsonString dataUsingEncoding:NSASCIIStringEncoding]];
	
	NSData *dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
	
	if(dataReply != nil)
	{
		NSString *str = [[NSString alloc] initWithData:dataReply encoding:NSUTF8StringEncoding];
    //		NSLog(@"ReceiptVerify response:\n %@", str);
		[str release];
	}
	
	[self restartApplication];
	
	//[[NSNotificationCenter defaultCenter] postNotificationName:reloadCellNotification object:nil];
}





@end
