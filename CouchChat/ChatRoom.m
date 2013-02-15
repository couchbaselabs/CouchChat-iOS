//
//  Chat.m
//  CouchChat
//
//  Created by Jens Alfke on 12/14/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import "ChatRoom.h"
#import "ChatStore.h"
#import <CouchbaseLite/CBLModelFactory.h>
#import <CouchbaseLite/CBLJSON.h>


@implementation ChatRoom
{
    CBLLiveQuery* _allPagesQuery;
    NSSet* _allPageTitles;
}

@dynamic title, owner_id, members;


- (id) initNewWithTitle: (NSString*)title inChatStore: (ChatStore*)chatStore {
    NSAssert(chatStore.username, @"No username set up yet");
    self = [super initWithNewDocumentInDatabase: chatStore.database];
    if (self) {
        self.autosaves = true;
        [self setValue: @"room" ofProperty: @"type"];
        [self setValue: chatStore.username ofProperty: @"owner_id"];
        self.title = title;
    }
    return self;
}


- (NSString*) chatID {
    return self.document.documentID;
}


- (ChatStore*) chatStore {
    return [ChatStore sharedInstance];  //FIX
}


- (NSString*) docIDForPageWithTitle: (NSString*)title {
    return [NSString stringWithFormat: @"%@:%@", self.chatID, title];
}


- (bool) editable {
    NSString* username = self.chatStore.username;
    if (!username)
        return false;
    return [self.owner_id isEqualToString: username] || [self.members containsObject: username];
}


- (bool) owned {
    NSString* username = self.chatStore.username;
    return username && [self.owner_id isEqualToString: username];
}


- (void) addMembers: (NSArray*)newMembers {
    NSArray* oldMembers = self.members;
    if (!oldMembers) {
        self.members = newMembers;
        return;
    }
    NSMutableOrderedSet* members = [NSMutableOrderedSet orderedSetWithArray: self.members];
    [members addObjectsFromArray: newMembers];
    self.members = members.array;
}


- (CBLQuery*) chatMessagesQuery {
    CBLQuery* query = [[self.database viewNamed: @"chatMessages"] query];
    query.startKey = @[self.chatID];
    query.endKey = @[self.chatID, @{}];
    return query;
}


- (BOOL) addChatMessage: (NSString*)markdown picture: (UIImage*)picture {
    NSString* createdAt = [CBLJSON JSONObjectWithDate: [NSDate date]];
    CBLNewRevision* rev = self.database.untitledDocument.newRevision;
    [rev.properties addEntriesFromDictionary: @{@"type": @"chat",
                                                @"chat_id": self.chatID,
                                                @"author": self.chatStore.username,
                                                @"created_at": createdAt}];
    rev[@"markdown"] = markdown;
    if (picture) {
        CBLAttachment* attachment = [[CBLAttachment alloc] initWithContentType: @"image/jpeg"
                                                  body: UIImageJPEGRepresentation(picture, 0.6)];
        [rev addAttachment: attachment named: @"picture"];
    }
    NSError* error;
    if (![rev save: &error]) {
        NSLog(@"WARNING: Couldn't save chat picture message: %@", error);
        return NO;
    }
    return YES;
}


@end
