//
//  NCDatabaseCategoriesViewController.m
//  Neocom
//
//  Created by Artem Shimanski on 20.11.16.
//  Copyright © 2016 Artem Shimanski. All rights reserved.
//

#import "NCDatabaseCategoriesViewController.h"
#import "NCDatabase.h"
#import "NCTableViewDefaultCell.h"
#import "NCDatabaseGroupsViewController.h"
#import "NCDatabaseTypesViewController.h"

@interface NCDatabaseCategoriesViewController()<UISearchResultsUpdating>
@property (nonatomic, strong) NSFetchedResultsController* results;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation NCDatabaseCategoriesViewController

- (void) viewDidLoad {
	[super viewDidLoad];
	[self setupSearchController];
	
	NSFetchRequest* request = [NCDBInvCategory fetchRequest];
	request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"published" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"categoryName" ascending:YES]];
	self.results = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:NCDatabase.sharedDatabase.viewContext sectionNameKeyPath:@"published" cacheName:nil];
	[self.results performFetch:nil];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"NCDatabaseGroupsViewController"]) {
		NCDatabaseGroupsViewController* controller = segue.destinationViewController;
		controller.category = [sender object];
		controller.title = controller.category.categoryName;
	}
}

#pragma mark - UITableViewDataSource

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return self.results.sections.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self.results.sections[section] numberOfObjects];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NCTableViewDefaultCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
	NCDBInvCategory* category = [self.results objectAtIndexPath:indexPath];
	cell.titleLabel.text = category.categoryName;
	cell.iconView.image = (id) category.icon.image.image ?: NCDBEveIcon.defaultCategoryIcon.image.image;
	cell.object = category;
	return cell;
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString* name = [self.results.sections[section] name];
	if ([name integerValue] == 0)
		return NSLocalizedString(@"Unpublished", nil);
	else
		return nil;
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
	NSPredicate* predicate;
	if (searchController.searchBar.text.length > 2) {
		predicate = [NSPredicate predicateWithFormat:@"typeName CONTAINS[C] %@", searchController.searchBar.text];
	}
	else
		predicate = [NSPredicate predicateWithValue:NO];
	NCDatabaseTypesViewController* controller = (NCDatabaseTypesViewController*) self.searchController.searchResultsController;
	controller.predicate = predicate;
	[controller reloadData];
}

#pragma mark - Private

- (void) setupSearchController {
	self.searchController = [[UISearchController alloc] initWithSearchResultsController:[self.storyboard instantiateViewControllerWithIdentifier:@"NCDatabaseTypesViewController"]];
	self.searchController.searchBar.searchBarStyle = UISearchBarStyleDefault;
	self.searchController.searchResultsUpdater = self;
	self.searchController.searchBar.barStyle = UIBarStyleBlack;
	self.searchController.hidesNavigationBarDuringPresentation = NO;
	self.tableView.backgroundView = [UIView new];
	self.tableView.tableHeaderView = self.searchController.searchBar;
	self.definesPresentationContext = YES;
}

@end
