//
//  AppDelegate.h
//  CouchChat
//
//  Created by Jens Alfke on 2/13/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <UIKit/UIKit.h>
@class ChatStore;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) UINavigationController *navigationController;

@property (strong, nonatomic) UISplitViewController *splitViewController;

@property (readonly) ChatStore* chatStore;

- (void)showAlert: (NSString*)message error: (NSError*)error fatal: (BOOL)fatal;

@end


extern AppDelegate* gAppDelegate;
