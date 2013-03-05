//
//  Chat.m
//  CouchChat
//
//  Created by Jens Alfke on 12/14/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import "ChatRoom.h"
#import "ChatStore.h"
#import "UserProfile.h"
#import <CouchbaseLite/CBLModelFactory.h>
#import <CouchbaseLite/CBLJSON.h>


@implementation ChatRoom
{
    CBLLiveQuery* _allPagesQuery;
    NSSet* _allPageTitles;
}

@dynamic title, owners, members;


- (id) initNewWithTitle: (NSString*)title inChatStore: (ChatStore*)chatStore {
    NSAssert(chatStore.username, @"No username set up yet");
    self = [super initWithNewDocumentInDatabase: chatStore.database];
    if (self) {
        self.owners = [NSArray arrayWithObject:chatStore.username];
        [self setValue: @"room" ofProperty: @"type"];
        [self setValue: [self chatID] ofProperty: @"channel_id"];
        self.title = title;
    }
    return self;
}

- (instancetype) initWithDocument: (CBLDocument*)document {
    self = [super initWithDocument: document];
    self.autosaves = true;
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


- (bool) isMember {
    NSString* username = self.chatStore.username;
    return username && ([self.members containsObject: username] ||
                        [self.owners containsObject: username]);
}


- (bool) isOwner {
    NSString* username = self.chatStore.username;
    return username && [self.owners containsObject: username];
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


static NSArray* removeFromArray(NSArray* array, id item) {
    NSMutableArray* nuArray = [array mutableCopy];
    [nuArray removeObject: item];
    return nuArray;
}


- (bool) removeMember: (UserProfile*)member
          withMessage: (NSString*)message
{
    NSString* memberID = member.username;
    if (![self.members containsObject: memberID])
        return true;    // If they're not a member, it's a no-op
    if (memberID != self.chatStore.username && !self.isOwner)
        return false;   // If *you're* not an owner, you can only remove yourself, not other people

    if (message)
        [self addChatMessage: message announcement: true picture: nil];
    self.owners = removeFromArray(self.owners, memberID);
    self.members = removeFromArray(self.members, memberID);
    return true;
}


- (CBLQuery*) chatMessagesQuery {
    CBLQuery* query = [[self.database viewNamed: @"chatMessages"] query];
    query.startKey = @[self.chatID];
    query.endKey = @[self.chatID, @{}];
    return query;
}


- (BOOL) addChatMessage: (NSString*)markdown
           announcement: (bool)announcement
                picture: (UIImage*)picture
{
    NSString* createdAt = [CBLJSON JSONObjectWithDate: [NSDate date]];
    CBLNewRevision* rev = self.database.untitledDocument.newRevision;
    [rev.properties addEntriesFromDictionary: @{@"type": @"chat",
                                                @"channel_id": self.chatID,
                                                @"author": self.chatStore.username,
                                                @"created_at": createdAt}];
    rev[@"markdown"] = markdown;
    if (announcement)
        rev[@"style"] = @"announcement";
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
