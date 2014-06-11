//
//  SyncManager.m
//  CouchChat
//
//  Created by Jens Alfke on 12/19/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import "SyncManager.h"
#import "LoginController.h"


NSString* const SyncManagerStateChangedNotification = @"SyncManagerStateChanged";


@implementation SyncManager
{
    NSMutableArray* _replications;
    bool _showingSyncButton;
    __weak id<SyncManagerDelegate> _delegate;
    LoginController* _loginController;
}


- (id) initWithDatabase: (CBLDatabase*)db {
    NSParameterAssert(db);
    self = [super init];
    if (self) {
        _database = db;
        _replications = [[NSMutableArray alloc] init];
        [self addReplications: db.allReplications];
    }
    return self;
}


@synthesize delegate=_delegate, replications=_replications, status=_status;


- (void) addReplication: (CBLReplication*)repl {
    if (![_replications containsObject: repl]) {
        [_replications addObject: repl];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(replicationProgress:)
                                                     name: kCBLReplicationChangeNotification
                                                   object: repl];
        if (!_syncURL)
            _syncURL = repl.remoteURL;
        if (repl.continuous)
            _continuous = true;
        if ([_delegate respondsToSelector: @selector(syncManager:addedReplication:)])
            [_delegate syncManager: self addedReplication: repl];
    }
}


- (void) addReplications: (NSArray*)replications {
    for (CBLReplication* repl in replications) {
        [self addReplication: repl];
    }
}


- (void) forgetReplication: (CBLReplication*)repl {
    [_replications removeObject: repl];
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: kCBLReplicationChangeNotification
                                                  object: repl];
}


- (void) forgetAll {
    for (CBLReplication* repl in _replications) {
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: kCBLReplicationChangeNotification
                                                      object: repl];
    }
    _replications = [[NSMutableArray alloc] init];
    _syncURL = nil;
}


- (void) setSyncURL: (NSURL*)url {
    if (url == _syncURL || [url isEqual: _syncURL])
        return;
    [self forgetAll];
    if (url) {
        CBLReplication *pullReplication = [self.database createPullReplication:url];
        [pullReplication setContinuous:YES];
        [self addReplication: pullReplication];
        
        CBLReplication *pushReplication = [self.database createPushReplication:url];
        [pushReplication setContinuous:YES];
        [self addReplication: pushReplication];
    }
}


- (void) setContinuous:(bool)continuous {
    _continuous = continuous;
    for (CBLReplication* repl in _replications)
        repl.continuous = continuous;
}


- (void) setUsername: (NSString*)username password: (NSString*)password {
    _loginController = nil;
    NSURLCredential* cred = [NSURLCredential credentialWithUser: username
                                                       password: password
                                                    persistence: NSURLCredentialPersistencePermanent];
    for (CBLReplication* repl in _replications) {
        repl.credential = cred;
    }
}


- (void) loginCanceled {
    _loginController = nil;
}


- (void) syncNow {
    for (CBLReplication* repl in _replications) {
        if (!repl.continuous)
            [repl start];
    }
}


- (void) replicationProgress: (NSNotificationCenter*)n {
    bool active = false;
    unsigned completed = 0, total = 0;
    CBLReplicationStatus status = kCBLReplicationStopped;
    NSError* error = nil;
    for (CBLReplication* repl in _replications) {
        status = MAX(status, repl.status);
        if (!error)
            error = repl.error;
        if (repl.status == kCBLReplicationActive) {
            active = true;
            completed += repl.completedChangesCount;
            total += repl.changesCount;
        }
    }

    if (error != _error && error.code == 401) {
        // Auth needed (or auth is incorrect). See if the delegate wants to do its own auth;
        // otherwise put up a username/password login panel:
        if (![_delegate respondsToSelector: @selector(syncManagerShouldPromptForLogin:)] ||
                [_delegate syncManagerShouldPromptForLogin: self]) {
            if (!_loginController) {
                NSString* user = [_replications[0] credential].user;
                _loginController = [[LoginController alloc] initWithURL: self.syncURL username: user];
                _loginController.delegate = self;
                [_loginController run];
            }
            error = nil;
        }
    }

    if (active != _active || completed != _completed || total != _total || status != _status
                          || error != _error) {
        _active = active;
        _completed = completed;
        _total = total;
        _progress = (completed / (float)MAX(total, 1u));
        _status = status;
        _error = error;
        NSLog(@"SYNCMGR: active=%d; status=%d; %u/%u; %@",
              active, status, completed, total, error.localizedDescription); //FIX: temporary logging
        if ([_delegate respondsToSelector: @selector(syncManagerProgressChanged:)])
            [_delegate syncManagerProgressChanged: self];
        [[NSNotificationCenter defaultCenter]
                                        postNotificationName: SyncManagerStateChangedNotification
                                                      object: self];
    }
}


@end
