//
//  Chat.h
//  CouchChat
//
//  Created by Jens Alfke on 12/14/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>
@class ChatStore;


/** One chat in the database. */
@interface ChatRoom : CBLModel

- (id) initNewWithTitle: (NSString*)title inChatStore: (ChatStore*)chatStore;

@property (readonly) ChatStore* chatStore;

@property (readonly) NSString* chatID;

@property (readwrite) NSString* title;

@property (readonly) NSString* owner_id;
@property (copy) NSArray* members;

- (void) addMembers: (NSArray*)newMembers;

@property (readonly) CBLQuery* chatMessagesQuery;

- (BOOL) addChatMessage: (NSString*)markdown
                picture: (UIImage*)picture;

@end


/*  A chat root document in JSON form:
    {
        "_id": "5737529525067657",
        "_rev": "29-d3aad012fc362578e8a9b652918f419d",
        "type": "room",
        "chat_id" : "5737529525067657",
        "title": "Mobile Dev",
        "tags": "Mobile, Dev, Couchbase",
        "members": "@jchris @snej @mschoch",
        "markdown": "Topics in Mobile!\n\n- HostedCouchbase\n- AccessControl\n- SyncProtocol\n- DeveloperFlow\n- CouchbaseServer\n",
        "created_at": "2012-12-09T06:05:55.031Z",
        "updated_at": "2012-12-16T01:33:01.909Z"
    }
*/