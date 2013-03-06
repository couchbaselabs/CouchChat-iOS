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
    NSArray* _users;
    __weak id<UserPickerControllerDelegate> _delegate;
    bool _started;
}

- (id) initWithUsers: (NSArray*)users
            delegate: (id<UserPickerControllerDelegate>)delegate
{
    self = [super initWithNibName: @"THContactPickerViewController" bundle: nil];
    if (self) {
        _users = [users copy];
        _delegate = delegate;
        
        NSMutableArray* names = [NSMutableArray array];
        for (UserProfile* user in _users) {
            NSString* displayName = user.displayName;
            if ([names containsObject: displayName])
                displayName = user.username;    // don't allow duplicates in the list
            [names addObject: displayName];
        }
        
        self.contacts = names;
        
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

- (void) selectUser: (UserProfile*)user {
    [self view]; // force nib to load
    NSUInteger index = [_users indexOfObject: user];
    if (index == NSNotFound)
        return;
    NSString* username = self.contacts[index];
    [self selectContact: username];
}

- (NSArray*) selectedUsers {
    // Map the superclass's selected names to the corresponding UserProfile objects:
    NSMutableArray* users = [NSMutableArray array];
    for (NSString* contact in self.selectedContacts) {
        NSUInteger index = [self.contacts indexOfObject: contact];
        [users addObject: _users[index]];
    }
    return users;
}

- (IBAction) start: (id)sender {
    _started = true;
    [_delegate userPickerController: self pickedUsers: self.selectedUsers];
}

@end
