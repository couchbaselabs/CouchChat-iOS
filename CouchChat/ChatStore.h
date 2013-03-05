//
//  ChatStore.h
//  CouchChat
//
//  Created by Jens Alfke on 12/18/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CouchbaseLite/CouchbaseLite.h>
@class ChatRoom, UserProfile;


/** Chat interface to a CouchbaseLite database. This is the root of the object model. */
@interface ChatStore : NSObject

- (id) initWithDatabase: (CBLDatabase*)database;

+ (ChatStore*) sharedInstance;

@property (readonly) CBLDatabase* database;

// CHATS:

@property (readonly, copy) NSArray* allChats;

- (ChatRoom*) newChatWithTitle: (NSString*)title;

// USERS:

/** The local logged-in user */
@property (nonatomic, readonly) UserProfile* user;

/** The local logged-in user's username. */
@property (nonatomic, copy) NSString* username;

/** Gets a UserProfile for a user given their username. */
- (UserProfile*) profileWithUsername: (NSString*)username;

/** Looks up a picture for a username, either from a UserProfile or from gravatar.com. */
- (UIImage*) pictureForUsername: (NSString*)username;

- (void) setMyProfileName: (NSString*)name nick: (NSString*)nick;
- (void) setMyProfilePicture:(UIImage *)picture;

@property (readonly) CBLQuery* allUsersQuery;
@property (readonly) NSArray* allOtherUsers;    /**< UserProfile objects of other users */

@end
