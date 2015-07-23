//
//  Chat.h
//  CouchChat
//
//  Created by Jens Alfke on 12/14/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>
@class ChatStore, UserProfile;


/** One chat in the database. */
@interface ChatRoom : CBLModel

+ (id) chatWithTitle: (NSString*)title
         inChatStore: (ChatStore*)chatStore;

@property (readonly) ChatStore* chatStore;

@property (readonly) NSString* chatID;

@property (readwrite) NSString* title;
@property (readonly) NSString* displayName;

@property (readonly) NSDate* modDate;
@property (readonly) UserProfile* lastSender;

// Membership:

@property (copy) NSArray* members;
@property (copy) NSArray* owners;

@property (readonly) NSOrderedSet* allMemberProfiles;

@property (readonly) bool isMember;
@property (readonly) bool isOwner;

- (void) addMembers: (NSArray*)newMembers;
- (bool) removeMember: (UserProfile*)member
          withMessage: (NSString*)message;

// Messages:

@property (readonly) unsigned unreadMessageCount;

- (void) markAsRead;

@property (readonly) CBLQuery* chatMessagesQuery;

- (BOOL) addChatMessage: (NSString*)markdown
           announcement: (bool)announcement
                picture: (UIImage*)picture;

// Internal use only
- (void) setMessageCount: (NSUInteger)messageCount
                 modDate: (NSDate*)modDate
              lastSender: (NSString*)lastSender;

@end


// Posted when a chat room's unreadCount or modDate change
extern NSString* const kChatRoomStatusChangedNotification;


/*  A chat root document in JSON form:
    {
        "_id": "5737529525067657",
        "_rev": "29-d3aad012fc362578e8a9b652918f419d",
        "type": "room",
        "channel_id" : "5737529525067657",
        "title": "Mobile Dev",
        "tags": "Mobile, Dev, Couchbase",
        "members": ["@jchris", "@snej", "@mschoch"],
        "owners": ["@amysue"],
        "markdown": "Topics in Mobile!\n\n- HostedCouchbase\n- AccessControl\n- SyncProtocol\n- DeveloperFlow\n- CouchbaseServer\n",
        "created_at": "2012-12-09T06:05:55.031Z",
        "updated_at": "2012-12-16T01:33:01.909Z"
    }
*/