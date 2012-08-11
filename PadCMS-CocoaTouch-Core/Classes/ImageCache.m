//
//  ImageCache.m
//  PadCMS-CocoaTouch-Core
//
//  Created by Alexey Igoshev on 8/6/12.
//  Copyright (c) 2012 Adyax. All rights reserved.
//

#import "ImageCache.h"
#import "PCPageElement.h"
#import "UIImage+ImmediateLoading.h"
#import "PCPage.h"

@interface ImageCache ()
@property (atomic, retain) NSArray* currentPages;

@end

@implementation ImageCache
@synthesize elementCache=_elementCache;
@synthesize operations=_operations;
@synthesize queue=_queue;
@synthesize callbackQueue = _callbackQueue;
@synthesize currentPages=_currentPages;

+ (ImageCache *)sharedImageCache
{
   	static ImageCache *instance = nil;
	static dispatch_once_t oncePredicate;
	dispatch_once(&oncePredicate, ^{
		instance = [[self alloc] init];
	});
	
	return instance;
}

-(void)dealloc
{
	if (_callbackQueue) { 
        dispatch_release(_callbackQueue);
        _callbackQueue = NULL;
    }

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_queue cancelAllOperations];
	[_elementCache release], _elementCache = nil;
	[_operations release], _operations = nil;
	[_queue release], _queue = nil;
	[_currentPages release], _currentPages = nil;
	
	[super dealloc];
}

- (void)setCallbackQueue:(dispatch_queue_t)callbackQueue {
    if (callbackQueue != _callbackQueue) {
        if (_callbackQueue) {
            dispatch_release(_callbackQueue);
            _callbackQueue = NULL;
        }
		
        if (callbackQueue) {
            dispatch_retain(callbackQueue);
            _callbackQueue = callbackQueue;
        }
    }    
}


- (id)init
{
    if ((self = [super init]))
    {
        // Init the memory cache
        _operations = [[NSMutableDictionary alloc] init];
		_elementCache = [[NSMutableDictionary alloc] init];
		_queue = [[NSOperationQueue alloc] init];
		_queue.maxConcurrentOperationCount = 1;
		
		self.callbackQueue = dispatch_queue_create("com.padcms.image.load", NULL);
        		
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
	}
	
    return self;
}

-(void)clearMemory
{
	//[_queue cancelAllOperations];
//	[_operations removeAllObjects];
	[_elementCache removeAllObjects];
}

-(void)storeTileForElement:(PCPageElement *)element withIndex:(NSUInteger)index
{
	NSString* path = [element resourcePathForTileIndex:index];
	UIImage* image = [[[UIImage alloc] initImmediateLoadWithContentsOfFile:path] retain];
	//UIImage* image = [[UIImage alloc] initWithContentsOfFile:path];
	if (!image)
	{
		NSLog(@"ERRRor!!! - %@, %d", path, index);
		return;
	}
	NSNumber* elementIdentifier = [NSNumber numberWithInt:element.identifier];
	if (![self.elementCache objectForKey:elementIdentifier])
	{
		[self.elementCache setObject:[NSMutableDictionary dictionary] forKey:elementIdentifier];
	}
	
	[[self.elementCache objectForKey:elementIdentifier] setObject:image forKey:[NSNumber numberWithInteger:index]];
	[image release];
	
	
	
}

-(void)clearMemoryForElement:(PCPageElement *)element
{
}


-(NSArray*)getNeighborsForPage:(PCPage*)page
{
	NSMutableArray* array = [NSMutableArray arrayWithObject:page];
	if (page.leftPage) [array addObject:page.leftPage];
	if (page.rightPage) [array addObject:page.rightPage];
	if (page.topPage) [array addObject:page.topPage];
	if (page.bottomPage) [array addObject:page.bottomPage];
	return [NSArray arrayWithArray:array];
	
}

-(void)loadPrimaryImagesForPage:(PCPage*)aPage
{
	dispatch_async(self.callbackQueue, ^{
		NSInteger maxIndex = ceilf(1024.0f / kDefaultTileSize) * ceilf(768.0f / kDefaultTileSize);
		
		self.currentPages = [self getNeighborsForPage:aPage];
		
		for (PCPage* page in self.currentPages) {
			PCPageElement* bodyElement = [page firstElementForType:PCPageElementTypeBody];
			if (![self.elementCache objectForKey:[NSNumber numberWithInt:bodyElement.identifier]])
			{
				for (int i = 1; i <=maxIndex; ++i) {
					NSBlockOperation* operation = [NSBlockOperation blockOperationWithBlock:^{
						[self storeTileForElement:bodyElement withIndex:i];
					}];
					[self.queue addOperation:operation];
				}
			}
			
			
			for (PCPageElement* element in page.primaryElements) {
				if ([self.elementCache objectForKey:[NSNumber numberWithInt:element.identifier]]) continue;
				if (![element.fieldTypeName isEqualToString:PCPageElementTypeBody] &&
					![element.fieldTypeName isEqualToString:PCPageElementTypeVideo] &&
					![element.fieldTypeName isEqualToString:PCPageElementTypeSound] &&
					![element.fieldTypeName isEqualToString:PCPageElementTypeHtml] &&
					![element.fieldTypeName isEqualToString:PCPageElementTypeHtml5] &&
					![element.fieldTypeName isEqualToString:PCPageElementType3D])
				{
					for (int i = 1; i <=maxIndex; ++i) {
						NSBlockOperation* operation = [NSBlockOperation blockOperationWithBlock:^{
							[self storeTileForElement:element withIndex:i];
						}];
						[self.queue addOperation:operation];
					}
				}
			}
		}
		
		
		
	});

}

-(void)clearMemoryForElement:(PCPageElement *)element withIndex:(NSUInteger)index
{
	
}

@end
