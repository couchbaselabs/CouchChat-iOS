//
//  UserPickerController.m
//  CouchChat
//
//  Created by Jens Alfke on 3/4/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "UserPickerController.h"
#import "THContactPickerView.h"
#import "UserProfile.h"

@interface THContactPickerView (Private)
@property (readonly) UITextView* textView;
@end


@interface UserPickerController ()

@end

@implementation UserPickerController
{
    __weak id<UserPickerControllerDelegate> _delegate;
    bool _started;
}

- (id) initWithUsers: (NSArray*)users
            delegate: (id<UserPickerControllerDelegate>)delegate
{
    self = [super initWithNibName: @"THContactPickerViewController" bundle: nil];
    if (self) {
        _delegate = delegate;
        
        self.contacts = [users sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [[obj1 displayName] localizedCaseInsensitiveCompare: [obj2 displayName]];
        }];
        //self.tableView
        
        self.title = @"Invite To Chat";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.contactPickerView setPlaceholderString:@"Choose people…"];
    UIBarButtonItem* startButton = [[UIBarButtonItem alloc] initWithTitle: @"Start"
                                                                    style: UIBarButtonItemStyleDone
                                                                   target: self
                                                                   action: @selector(start:)];
    self.navigationItem.rightBarButtonItem = startButton;
}

- (void)viewDidDisappear:(BOOL)animated {
    if (!_started)
        [_delegate userPickerController: self pickedUsers: nil];
}

- (IBAction) start: (id)sender {
    _started = true;
    [_delegate userPickerController: self pickedUsers: self.selectedContacts];
}

@end
