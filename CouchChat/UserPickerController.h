//
//  UserPickerController.h
//  CouchChat
//
//  Created by Jens Alfke on 3/4/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "THContactPickerViewController.h"
@protocol UserPickerControllerDelegate;
@class UserProfile;


@interface UserPickerController : THContactPickerViewController

- (id) initWithUsers: (NSArray*)users
            delegate: (id<UserPickerControllerDelegate>)delegate;

- (void) selectUser: (UserProfile*)user;

@end


@protocol UserPickerControllerDelegate <NSObject>

- (void) userPickerController: (UserPickerController*)controller
                  pickedUsers: (NSArray*)users;

@end
