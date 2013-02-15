//
//  SyncManager.h
//  TouchWiki
//
//  Created by Jens Alfke on 12/19/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>
@protocol SyncManagerDelegate;


@interface SyncManager : NSObject

- (id) initWithDatabase: (CBLDatabase*)database;

@property (readonly) CBLDatabase* database;
@property (nonatomic, weak) id<SyncManagerDelegate> delegate;

@property (nonatomic) NSURL* syncURL;
@property (nonatomic) bool continuous;

@property (nonatomic, readonly) NSArray* replications;

// These are not KVO-observable; observe SyncManagerStateChangedNotification instead
@property (nonatomic, readonly) unsigned completed, total;
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) bool active;
@property (nonatomic, readonly) CBLReplicationMode mode;
@property (nonatomic, readonly) NSError* error;

- (void) syncNow;

- (void) setUsername: (NSString*)username password: (NSString*)password;
- (void) loginCanceled;

@end


/** Posted by a SyncManager instance when its replication state properties change. */
extern NSString* const SyncManagerStateChangedNotification;


@protocol SyncManagerDelegate <NSObject>
@optional
- (void) syncManagerProgressChanged: (SyncManager*)manager;
- (void) syncManager: (SyncManager*)manager addedReplication: (CBLReplication*)replication;
- (bool) syncManagerShouldPromptForLogin: (SyncManager*)manager;

@end