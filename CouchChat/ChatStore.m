//
//  ChatStore.m
//  CouchChat
//
//  Created by Jens Alfke on 12/18/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import "ChatStore.h"
#import "ChatRoom.h"
#import <CouchbaseLite/CBLModelFactory.h>


static ChatStore* sInstance;


@implementation ChatStore
{
    NSString* _username;
}


- (id) initWithDatabase: (CBLDatabase*)database {
    self = [super init];
    if (self) {
        NSAssert(!sInstance, @"Cannot create more than one ChatStore");
        sInstance = self;
        _database = database;
        [_database.modelFactory registerClass: [ChatRoom class] forDocumentType: @"chat"];

        // Map function for finding chats by title
        CBLView* view = [_database viewNamed: @"chatsByTitle"];
        [view setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqualToString: @"room"]) {
                NSString* title = doc[@"title"];
                if (title)
                    emit(title, nil);
            }
        }) version: @"2"];
        _allChatsQuery = [[view query] asLiveQuery];

        // Map function for getting chat messages
        [[_database viewNamed: @"chatMessages"] setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqualToString: @"chat"]) {
                NSString* markdown = doc[@"markdown"] ?: @"";
                bool hasAttachments = [doc[@"_attachments"] count] > 0;
                emit(@[doc[@"channel_id"], doc[@"created_at"]],
                     @[doc[@"author"], markdown, @(hasAttachments)]);
            }
        }) version: @"3"];
    }
    return self;
}


+ (ChatStore*) sharedInstance {
    return sInstance;
}


- (NSString*) username {
    //FIX: This would be better stored in a _local document in the database
    return [[NSUserDefaults standardUserDefaults] stringForKey: @"UserName"];
}


- (void) setUsername:(NSString *)username {
    NSLog(@"Setting chat username to '%@'", username);
    [[NSUserDefaults standardUserDefaults] setObject: username forKey: @"UserName"];
}


- (ChatRoom*) chatWithTitle: (NSString*)title {
    for (CBLQueryRow* row in _allChatsQuery.rows) {
        if ([row.key isEqualToString: title])
            return [ChatRoom modelForDocument: row.document];
    }
    return nil;
}


- (ChatRoom*) newChatWithTitle: (NSString*)title {
    return [[ChatRoom alloc] initNewWithTitle: title inChatStore: self];
}


- (UIImage*) avatarForUser: (NSString*)user {
    return nil;     // TODO
}


@end
