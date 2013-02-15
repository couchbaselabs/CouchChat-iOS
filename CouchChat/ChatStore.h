//
//  ChatStore.h
//  CouchChat
//
//  Created by Jens Alfke on 12/18/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CouchbaseLite/CouchbaseLite.h>
@class ChatRoom;


/** Chat interface to a CouchbaseLite database. This is the root of the object model. */
@interface ChatStore : NSObject

- (id) initWithDatabase: (CBLDatabase*)database;

+ (ChatStore*) sharedInstance;

@property (readonly) CBLDatabase* database;

@property (readonly) CBLLiveQuery* allChatsQuery;

- (ChatRoom*) chatWithTitle: (NSString*)title;

- (ChatRoom*) newChatWithTitle: (NSString*)title;

@property (strong) NSString* username;

@end
