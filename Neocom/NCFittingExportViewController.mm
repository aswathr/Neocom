//
//  NCFittingExportViewController.m
//  Neocom
//
//  Created by Артем Шиманский on 13.04.15.
//  Copyright (c) 2015 Artem Shimanski. All rights reserved.
//

#import "NCFittingExportViewController.h"
#import "ASHTTPServer.h"
#import "UIDevice+IP.h"
#import "NCStorage.h"
#import "NCShipFit.h"
#import "NCPOSFit.h"
#import "NCDatabase.h"
#import "NSArray+Neocom.h"
#import "UIColor+Neocom.h"
#import "NCLoadoutsParser.h"
#import "UIAlertView+Block.h"

@interface NCFittingExportViewController ()<ASHTTPServerDelegate>
@property (nonatomic, strong) ASHTTPServer* server;
@property (nonatomic, strong) NSString* html;
@property (nonatomic, strong) NSMutableArray* fits;
@property (nonatomic, strong) NSString* allFits;

- (void) reloadWithCompletionHandler:(void(^)()) completionHandler;
- (void) performImportLoadouts:(NSArray*) loadouts withCompletionHandler:(void(^)()) completionHandler;
@end

@implementation NCFittingExportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	self.view.backgroundColor = [UIColor appearanceTableViewBackgroundColor];
    // Do any additional setup after loading the view.
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	self.server = [[ASHTTPServer alloc] initWithName:NSLocalizedString(@"Neocom", nil) port:8080];
	self.server.delegate = self;
	NSError* error = nil;
	
	NSString* address = nil;
	if ([self.server startWithError:&error]) {
		address = [UIDevice localIPAddress];
	}
	
	if (address) {
		self.urlLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Your address is\nhttp://%@:8080", nil), address];
	}
	else {
		self.urlLabel.text = NSLocalizedString(@"Check your Wi-Fi settings", nil);
		self.server = nil;
	}
	

	[self reloadWithCompletionHandler:nil];
}

- (void) viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	self.server = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onClose:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - ASHTTPServerDelegate

- (void) server:(ASHTTPServer*) server didReceiveRequest:(NSURLRequest*) request {
	__block NSData* bodyData = nil;
	NSString* path = [request.URL.path lowercaseString];
	NSString* extension = path.pathExtension;
	
	NSMutableDictionary* headerFields = [NSMutableDictionary new];
	NSInteger statusCode = 404;
	
	if ([extension isEqualToString:@"png"]) {
		NCDBEveIcon* icon = [NCDBEveIcon eveIconWithIconFile:[path lastPathComponent]];
		if (icon) {
			UIImage* image = icon.image.image;
			bodyData = UIImagePNGRepresentation(image);
			headerFields[@"Content-Type"] = @"image/png";
			statusCode = 200;
		}
	}
	else if ([extension isEqualToString:@"xml"]) {
		if ([[path lastPathComponent] isEqualToString:@"allfits.xml"]) {
			statusCode = 200;
			bodyData = [self.allFits dataUsingEncoding:NSUTF8StringEncoding];
		}
		else {
			NSArray* c = [[[path lastPathComponent] stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
			if (c.count == 2) {
				NSInteger i = [[c lastObject] integerValue] - 1;
				if (i >= 0 && i < self.fits.count) {
					NSString* fit = self.fits[i];
					statusCode = 200;
					bodyData = [fit dataUsingEncoding:NSUTF8StringEncoding];
				}
			}
		}
		if (statusCode == 200) {
			headerFields[@"Content-Type"] = @"application/xml";
			headerFields[@"Content-Disposition"] = [NSString stringWithFormat:@"attachment; filename=\"%@\"", [path lastPathComponent]];
		}
	}
	else {
		if ([[[path lastPathComponent] lowercaseString] isEqualToString:@"upload"]) {
			NSString* contentType = request.allHTTPHeaderFields[@"Content-Type"];
			NSString* boundary;
			for (NSString* record in [contentType componentsSeparatedByString:@";"]) {
				NSArray* components = [record componentsSeparatedByString:@"="];
				if (components.count == 2) {
					NSString* key = [components[0] lowercaseString];
					if ([key rangeOfString:@"boundary"].location != NSNotFound) {
						boundary = components[1];
					}
				}
			}
			if (boundary) {
				NSString* endMarker = [NSString stringWithFormat:@"--%@--", boundary];
				NSString* bodyString = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
				NSInteger start = [bodyString rangeOfString:@"\r\n\r\n"].location;
				NSInteger end = [bodyString rangeOfString:endMarker].location;
				if (start != NSNotFound && end != NSNotFound && start + 4 < end) {
					NSString* xml = [bodyString substringWithRange:NSMakeRange(start + 4, end - start - 4)];
					NSArray* loadouts = [NCLoadoutsParser parserEveXML:xml];
					if (loadouts.count > 0) {
						[self performImportLoadouts:loadouts withCompletionHandler:^{
							[self reloadWithCompletionHandler:^{
								headerFields[@"Content-Type"] = @"text/html; charset=UTF-8";
								bodyData = [self.html dataUsingEncoding:NSUTF8StringEncoding];
								
								headerFields[@"Content-Length"] = [NSString stringWithFormat:@"%ld", (long) bodyData.length];
								
								NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
																						  statusCode:200
																							bodyData:bodyData
																						headerFields:headerFields];
								[server finishRequest:request withResponse:response];
							}];
						}];
						return;
					}
				}
			}
			[[UIAlertView alertViewWithTitle:NSLocalizedString(@"Error", nil)
									 message:NSLocalizedString(@"Invalid file format", nil)
						   cancelButtonTitle:NSLocalizedString(@"Close", nil)
						   otherButtonTitles:nil
							 completionBlock:nil
								 cancelBlock:nil] show];
		}
		statusCode = 200;
		headerFields[@"Content-Type"] = @"text/html; charset=UTF-8";
		bodyData = [self.html dataUsingEncoding:NSUTF8StringEncoding];
	}
	
	headerFields[@"Content-Length"] = [NSString stringWithFormat:@"%ld", (long) bodyData.length];
	
	NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
															  statusCode:statusCode
																bodyData:bodyData
															headerFields:headerFields];
	[server finishRequest:request withResponse:response];
}

#pragma mark - Private

- (void) reloadWithCompletionHandler:(void(^)()) completionHandler {
	NSMutableString* htmlTemplate = [[NSMutableString alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"fits" ofType:@"html"] encoding:NSUTF8StringEncoding error:nil];
	NSString* headerTemplate;
	NSString* rowTemplate;
	
	
	NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:@"\\{header\\}(.*)\\{/header\\}"
																				options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
																				  error:nil];
	NSTextCheckingResult* result = [expression firstMatchInString:htmlTemplate options:0 range:NSMakeRange(0, htmlTemplate.length)];
	if (result.numberOfRanges == 2) {
		headerTemplate = [htmlTemplate substringWithRange:[result rangeAtIndex:1]];
		[htmlTemplate replaceCharactersInRange:[result rangeAtIndex:0] withString:@""];
	}
	
	expression = [NSRegularExpression regularExpressionWithPattern:@"\\{row\\}(.*)\\{/row\\}"
														   options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
															 error:nil];
	result = [expression firstMatchInString:htmlTemplate options:0 range:NSMakeRange(0, htmlTemplate.length)];
	if (result.numberOfRanges == 2) {
		rowTemplate = [htmlTemplate substringWithRange:[result rangeAtIndex:1]];
		[htmlTemplate replaceCharactersInRange:[result rangeAtIndex:0] withString:@""];
	}
	
	NSMutableArray* fits = [NSMutableArray new];
	NSMutableString* allFits = [NSMutableString new];
	[[self taskManager] addTaskWithIndentifier:NCTaskManagerIdentifierAuto
										 title:NCTaskManagerDefaultTitle
										 block:^(NCTask *task) {
											 NSMutableArray* sections = [NSMutableArray new];
											 NCStorage* storage = [NCStorage sharedStorage];
											 NSMutableString* body = [NSMutableString new];
											 NSManagedObjectContext* context = [NSThread isMainThread] ? storage.managedObjectContext : storage.backgroundManagedObjectContext;
											 [context performBlockAndWait:^{
												 [allFits appendString:@"<?xml version=\"1.0\" ?>\n<fittings>\n"];
												 NSArray* shipLoadouts = [[storage shipLoadouts] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"type.typeName" ascending:YES]]];
												 task.progress = 0.25;
												 
												 for (NSArray* array in [shipLoadouts arrayGroupedByKey:@"type.group.groupID"])
													 [sections addObject:[array mutableCopy]];
												 
												 task.progress = 0.5;
												 [sections sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
													 NCLoadout* a = [obj1 objectAtIndex:0];
													 NCLoadout* b = [obj2 objectAtIndex:0];
													 return [a.type.group.groupName compare:b.type.group.groupName];
												 }];
												 
												 task.progress = 0.75;
												 
												 int32_t i = 0;
												 for (NSArray* section in sections) {
													 NCLoadout* loadout = [section lastObject];
													 [body appendFormat:headerTemplate, loadout.type.group.groupName];
													 for (NCLoadout* loadout in section) {
														 NCShipFit* fit = [[NCShipFit alloc] initWithLoadout:loadout];
														 [fits addObject:[fit eveXMLRepresentation]];
														 [allFits appendString:[fit eveXMLRecordRepresentation]];
														 NCDBInvType* type = loadout.type;
														 [body appendFormat:rowTemplate,
														  type.icon.iconFile, type.typeName, loadout.name, type.typeID, ++i, fit.dnaRepresentation];
													 }
												 }
												 
												 task.progress = 1.0;
												 
												 [allFits appendString:@"</fittings>"];
												 
											 }];
											 [htmlTemplate replaceOccurrencesOfString:@"{body}" withString:body options:0 range:NSMakeRange(0, htmlTemplate.length)];
										 } completionHandler:^(NCTask *task) {
											 self.html = htmlTemplate;
											 self.fits = fits;
											 self.allFits = allFits;
											 if (completionHandler)
												 completionHandler();
										 }];
}

- (void) performImportLoadouts:(NSArray*) loadouts withCompletionHandler:(void(^)()) completionHandler {
	[[UIAlertView alertViewWithTitle:NSLocalizedString(@"Import", nil)
							 message:[NSString stringWithFormat:NSLocalizedString(@"Do you wish to import %ld loadouts?", nil), (long) loadouts.count]
				   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
				   otherButtonTitles:@[NSLocalizedString(@"Import", nil)]
					 completionBlock:^(UIAlertView *alertView, NSInteger selectedButtonIndex) {
						 if (selectedButtonIndex != alertView.cancelButtonIndex) {
							 NSManagedObjectContext* context = [[NCStorage sharedStorage] managedObjectContext];
							 [context performBlockAndWait:^{
								 for (NCLoadout* loadout in loadouts) {
									 [context insertObject:loadout];
									 [context insertObject:loadout.data];
								 }
								 NSError* error = nil;
								 [context save:&error];
							 }];
						 }
						 if (completionHandler)
							 completionHandler();
					 }
						 cancelBlock:^{
							 if (completionHandler)
								 completionHandler();
						 }] show];
}

@end