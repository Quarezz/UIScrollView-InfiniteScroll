//
//  TableViewController.m
//  InfiniteScrollViewDemo
//
//  Created by pronebird on 09/05/14.
//  Copyright (c) 2014 codeispoetry.ru. All rights reserved.
//

#import "TableViewController.h"
#import "UIApplication+NetworkIndicator.h"
#import "BrowserViewController.h"
#import "StoryModel.h"

#import "CustomInfiniteIndicator.h"
#import "UIScrollView+InfiniteScroll.h"

#define USE_AUTOSIZING_CELLS 1

static NSString *const kAPIEndpointURL = @"https://hn.algolia.com/api/v1/search_by_date?tags=story&hitsPerPage=%ld&page=%ld";
static NSString *const kShowBrowserSegueIdentifier = @"ShowBrowser";
static NSString *const kCellIdentifier = @"Cell";

static NSString *const kJSONResultsKey = @"hits";
static NSString *const kJSONNumPagesKey = @"nbPages";

@interface TableViewController()

@property NSMutableArray *stories;
@property NSInteger currentPage;
@property NSInteger numPages;

@end

@implementation TableViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
#if USE_AUTOSIZING_CELLS
    // enable auto-sizing cells on iOS 8
    if([self.tableView respondsToSelector:@selector(layoutMargins)]) {
        self.tableView.estimatedRowHeight = 88.0;
        self.tableView.rowHeight = UITableViewAutomaticDimension;
    }
#endif
    
    self.stories = [NSMutableArray new];
    self.currentPage = 0;
    self.numPages = 0;
    
    __weak typeof(self) weakSelf = self;
    
    // Create custom indicator
    CustomInfiniteIndicator *indicator = [[CustomInfiniteIndicator alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    
    // Set custom indicator
    self.tableView.infiniteScrollIndicatorView = indicator;
    
    // Set custom indicator margin
    self.tableView.infiniteScrollIndicatorMargin = 40;
    
    // Add infinite scroll handler
    [self.tableView addInfiniteScrollWithHandler:^(UITableView *tableView) {
        [weakSelf fetchData:^{
            // Finish infinite scroll animations
            [tableView finishInfiniteScroll];
        }];
    }];
    
    // Load initial data
    [self fetchData:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:kShowBrowserSegueIdentifier]) {
        NSIndexPath *selectedRow = [self.tableView indexPathForSelectedRow];
        BrowserViewController *controller = (BrowserViewController *)segue.destinationViewController;
        controller.story = self.stories[selectedRow.row];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.stories count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
    StoryModel *story = self.stories[indexPath.row];
    
    cell.textLabel.text = story.title;
    cell.detailTextLabel.text = story.author;

#if USE_AUTOSIZING_CELLS
    // enable auto-sizing cells on iOS 8
    if([tableView respondsToSelector:@selector(layoutMargins)]) {
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 0;
    }
#endif
    
    return cell;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if(buttonIndex == alertView.firstOtherButtonIndex) {
        [self fetchData:nil];
    }
}

#pragma mark - Private methods

- (void)showRetryAlertWithError:(NSError *)error {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error fetching data", @"")
                                                        message:error.localizedDescription
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                                              otherButtonTitles:NSLocalizedString(@"Retry", @""), nil];
    [alertView show];
}

- (void)handleResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    if(error) {
        [self showRetryAlertWithError:error];
        return;
    }
    
    NSError *JSONError;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
    
    if(JSONError) {
        [self showRetryAlertWithError:JSONError];
        return;
    }
    
    self.numPages = [responseDict[kJSONNumPagesKey] integerValue];
    self.currentPage++;
    
    NSArray *results = responseDict[kJSONResultsKey];
    
    for(NSDictionary *i in results) {
        [self.stories addObject:[StoryModel modelWithDictionary:i]];
    }
    
    [self.tableView reloadData];
}

- (void)fetchData:(void(^)(void))completion {
    NSInteger hits = CGRectGetHeight(self.tableView.bounds) / 44.0;
    NSString *URLString = [NSString stringWithFormat:kAPIEndpointURL, (long)hits, (long)self.currentPage];
    NSURL *requestURL = [NSURL URLWithString:URLString];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:response data:data error:error];
            
            [[UIApplication sharedApplication] stopNetworkActivity];
            
            if(completion) {
                completion();
            }
        });
    }];

    [[UIApplication sharedApplication] startNetworkActivity];
    
    // I run -[task resume] with delay because my network is too fast
    NSTimeInterval delay = (self.stories.count == 0 ? 0 : 5);
    
    [task performSelector:@selector(resume) withObject:nil afterDelay:delay];
}

@end
