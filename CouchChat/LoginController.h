//
//  LoginController.h
//  TouchWiki
//
//  Created by Jens Alfke on 1/3/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SyncManager;


/** Simple wrapper around a UIAlertView that prompts for a username and password. */
@interface LoginController : NSObject

- (id) initWithURL: (NSURL*)url username: (NSString*)username;

- (void) run;

@property (weak) SyncManager* delegate;

@end
