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
#import "PersonaController+UIKit.h"
#import <CouchbaseLite/CouchbaseLite.h>


#define kServerDBURLString @"http://mobile.hq.couchbase.com/chat"


AppDelegate* gAppDelegate;


@interface AppDelegate () <SyncManagerDelegate, PersonaControllerDelegate>
@end


@implementation AppDelegate
{
    CBLDatabase* _database;
    SyncManager* _syncManager;
    PersonaController* _personaController;
    bool _loggingIn;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    gAppDelegate = self;
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Initialize CouchbaseLite:
    NSError* error;
    _database = [[CBLManager sharedInstance] createDatabaseNamed: @"chat" error: &error];
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
    _syncManager.syncURL = [NSURL URLWithString: kServerDBURLString];
}


- (void) syncManagerProgressChanged: (SyncManager*)manager {
    if (_loggingIn) {
        CBLReplication* repl = manager.replications[0];
        if (repl.mode == kCBLReplicationIdle) {
            _loggingIn = false;
            // Pick up my username from the replication, on the first sync:
            NSString* username = repl.personaEmailAddress;
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
    // Display Persona login panel, not the default username/password one:
    if (!_personaController) {
        _loggingIn = true;
        _personaController = [[PersonaController alloc] init];
        NSArray* replications = _syncManager.replications;
        if (replications.count > 0)
            _personaController.origin = [replications[0] personaOrigin];
        _personaController.delegate = self;
        [_personaController presentModalInController: self.navigationController];
    }
    return false;
}


- (void) personaControllerDidCancel: (PersonaController*) personaController {
    [_personaController.viewController dismissViewControllerAnimated: YES completion: NULL];
    _personaController = nil;
}

- (void) personaController: (PersonaController*) personaController
           didFailWithReason: (NSString*) reason
{
    [self personaControllerDidCancel: personaController];
}

- (void) personaController: (PersonaController*) personaController
     didSucceedWithAssertion: (NSString*) assertion
{
    [self personaControllerDidCancel: personaController];
    for (CBLReplication* repl in _syncManager.replications) {
        [repl registerPersonaAssertion: assertion];
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
