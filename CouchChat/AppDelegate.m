//
//  AppDelegate.m
//  CouchChat
//
//  Created by Jens Alfke on 2/13/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "AppDelegate.h"
#import "ChatListController.h"
#import "ChatController.h"
#import "ChatStore.h"
#import "UserProfile.h"
#import "SyncManager.h"
#import "BrowserIDController+UIKit.h"
#import <CouchbaseLite/CouchbaseLite.h>


AppDelegate* gAppDelegate;


@interface AppDelegate () <SyncManagerDelegate, BrowserIDControllerDelegate>
@end


@implementation AppDelegate
{
    CBLDatabase* _database;
    SyncManager* _syncManager;
    BrowserIDController* _browserIDController;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    gAppDelegate = self;
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Initialize CouchbaseLite:
    NSError* error;
    _database = [[CBLManager sharedInstance] createDatabaseNamed: @"chats"
                                                                       error: &error];
    if (!_database)
        [self showAlert: @"Couldn't open database" error: error fatal: YES];

    _chatStore = [[ChatStore alloc] initWithDatabase: _database];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        // iPhone UI:
        ChatListController *listController = [[ChatListController alloc] initWithNibName:@"ChatListController_iPhone" bundle:nil];
        self.navigationController = [[UINavigationController alloc] initWithRootViewController:listController];
        self.window.rootViewController = self.navigationController;
    } else {
        // iPad UI:
        ChatListController *listController = [[ChatListController alloc] initWithNibName:@"ChatListController_iPad" bundle:nil];
        UINavigationController *masterNavigationController = [[UINavigationController alloc] initWithRootViewController:listController];
        
        ChatController *chatController = [[ChatController alloc] initWithNibName:@"ChatController_iPad" bundle:nil];
        UINavigationController *detailNavigationController = [[UINavigationController alloc] initWithRootViewController:chatController];
        self.navigationController = detailNavigationController;
    	
    	listController.chatController = chatController;
    	
        self.splitViewController = [[UISplitViewController alloc] init];
        self.splitViewController.delegate = chatController;
        self.splitViewController.viewControllers = @[masterNavigationController, detailNavigationController];
        
        self.window.rootViewController = self.splitViewController;
    }
    [self.window makeKeyAndVisible];

    [self setupSync];

    return YES;
}


#pragma mark - SYNC & LOGIN:


- (void) setupSync {
    _syncManager = [[SyncManager alloc] initWithDatabase: _database];
    _syncManager.delegate = self;
    // Configure replication:
    _syncManager.continuous = YES;
//    _syncManager.syncURL = [NSURL URLWithString: @"http://macbuild.local:4986/chat"];
    _syncManager.syncURL = [NSURL URLWithString: @"http://localhost:4984/sync_gateway"];
}


- (void) syncManagerProgressChanged: (SyncManager*)manager {
    if (_chatStore.username == nil) {
        CBLReplication* repl = manager.replications[0];
        if (repl.mode == kCBLReplicationIdle) {
            // Pick up my username from the replication, on the first sync:
            NSString* username = repl.browserIDEmailAddress;
            if (!username)
                username = repl.credential.user;
            if (username) {
                NSLog(@"Chat username = '%@'", username);
                _chatStore.username = username;
            }
        }
    }
}


- (bool) syncManagerShouldPromptForLogin: (SyncManager*)manager {
    // Display BrowserID login panel, not the default username/password one:
    if (!_browserIDController) {
        _browserIDController = [[BrowserIDController alloc] init];
        NSArray* replications = _syncManager.replications;
        if (replications.count > 0)
            _browserIDController.origin = [replications[0] browserIDOrigin];
        _browserIDController.delegate = self;
        [_browserIDController presentModalInController: self.navigationController];
    }
    return false;
}


- (void) browserIDControllerDidCancel: (BrowserIDController*) browserIDController {
    [_browserIDController.viewController dismissViewControllerAnimated: YES completion: NULL];
    _browserIDController = nil;
}

- (void) browserIDController: (BrowserIDController*) browserIDController
           didFailWithReason: (NSString*) reason
{
    [self browserIDControllerDidCancel: browserIDController];
}

- (void) browserIDController: (BrowserIDController*) browserIDController
     didSucceedWithAssertion: (NSString*) assertion
{
    [self browserIDControllerDidCancel: browserIDController];
    for (CBLReplication* repl in _syncManager.replications) {
        [repl registerBrowserIDAssertion: assertion];
    }
}


#pragma mark - ALERT:


// Display an error alert, without blocking.
// If 'fatal' is true, the app will quit when it's pressed.
- (void)showAlert: (NSString*)message error: (NSError*)error fatal: (BOOL)fatal {
    if (error) {
        message = [NSString stringWithFormat: @"%@\n\n%@", message, error.localizedDescription];
    }
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: (fatal ? @"Fatal Error" : @"Error")
                                                    message: message
                                                   delegate: (fatal ? self : nil)
                                          cancelButtonTitle: (fatal ? @"Quit" : @"Sorry")
                                          otherButtonTitles: nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    exit(0);
}


@end
