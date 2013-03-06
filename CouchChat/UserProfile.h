//
//  UserProfile.h
//  CouchChat
//
//  Created by Jens Alfke on 2/15/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>


/** Information about a user. */
@interface UserProfile : CBLModel

/** The user's unique identifier, used in the "author" property of chat messages. */
@property (readonly) NSString* username;

@property (readonly, copy) NSString* name;  /**< Person's name. */
@property (readonly, copy) NSString* nick;  /**< Nickname, aka "handle" or "screen name". */
@property (readonly, copy) NSString* email; /**< Primary email address. */

@property (readonly) NSString* displayName; /**< Best name to display (name, else username) */

/** Does this profile represent the logged-in user? */
@property (readonly) bool isMe;

/** A small picture for use as an avatar/userpic. */
@property (readonly, weak) UIImage* picture;

/** Maps a username to the document ID of the user's profile. */
+ (NSString*) docIDForUsername: (NSString*)username;

/** Creates a new UserProfile, presumably for the local logged-in user. */
+ (UserProfile*) createInDatabase: (CBLDatabase*)database
                     withUsername: (NSString*)username;

/** Synchronously loads an image from gravatar.com for the given email address. */
+ (UIImage*) loadGravatarForEmail: (NSString*)email;

+ (NSString*) usernameFromDocID: (NSString*)docID;

+ (NSString*) listOfNames: (id)userArrayOrSet;

@end
