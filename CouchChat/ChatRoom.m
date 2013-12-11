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


NSString* const kChatRoomStatusChangedNotification = @"ChatRoomStatusChanged";


@interface ChatRoom ()
@property (readwrite) unsigned unreadMessageCount;
@property (readwrite) NSDate* modDate;
@end


@implementation ChatRoom
{
    CBLLiveQuery* _allPagesQuery;
    NSSet* _allPageTitles;
    unsigned _messageCount;
    NSString* _lastSenderID;
}

@dynamic title, owners, members;

@synthesize modDate = _modDate, unreadMessageCount = _unreadMessageCount;


- (instancetype) initWithDocument: (CBLDocument*)document {
    // This is the designated initializer that's always called
    self = [super initWithDocument: document];
    self.autosaves = true;
    [self loadLocalState];
    return self;
}


// New-document initializer
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


- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@ '%@']",
            self.class, self.document.abbreviatedID, self.title];
}


- (NSString*) chatID {
    return self.document.documentID;
}


- (ChatStore*) chatStore {
    return [ChatStore sharedInstance];  //FIX?
}


- (NSString*) displayName {
    NSString* name = self.title;
    if (name)
        return name;
    return [NSString stringWithFormat: @"with %@",
            [UserProfile listOfNames: self.allMemberProfiles]];
}


#pragma mark - MEMBERSHIP:


- (UserProfile*) lastSender {
    if (!_lastSenderID)
        return nil;
    return [self.chatStore profileWithUsername: _lastSenderID];
}


- (NSOrderedSet*) allMemberProfiles {
    NSMutableOrderedSet* profiles = [NSMutableOrderedSet orderedSet];
    for (NSString* username in self.owners)
        [profiles addObject: [self.chatStore profileWithUsername: username]];
    for (NSString* username in self.members)
        [profiles addObject: [self.chatStore profileWithUsername: username]];
    return profiles;
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


#pragma mark - MESSAGES:


- (CBLQuery*) chatMessagesQuery {
    CBLQuery* query = [[self.database viewNamed: @"chatMessages"] createQuery];
    query.startKey = @[self.chatID];
    query.endKey = @[self.chatID, @{}];
    query.mapOnly = true;
    return query;
}


- (BOOL) addChatMessage: (NSString*)markdown
           announcement: (bool)announcement
                picture: (UIImage*)picture
{
    NSString* createdAt = [CBLJSON JSONObjectWithDate: [NSDate date]];
    CBLUnsavedRevision* rev = self.database.createDocument.newRevision;
    [rev.properties addEntriesFromDictionary: @{@"type": @"chat",
                                                @"channel_id": self.chatID,
                                                @"author": self.chatStore.username,
                                                @"created_at": createdAt}];
    rev[@"markdown"] = markdown;
    if (announcement)
        rev[@"style"] = @"announcement";
    if (picture) {
        [rev setAttachmentNamed: @"picture"
                withContentType: @"image/jpeg"
                        content: UIImageJPEGRepresentation(picture, 0.6)];
    }

    // Bumping the message count has the effect of not treating this newly-added message as
    // unread -- when the ChatStore's view updates and it calls -setMessageCount:modDate: on me,
    // the new message count will match my _messageCount so I won't change my _unreadCount.
    ++_messageCount;

    NSError* error;
    if (![rev save: &error]) {
        --_messageCount;  // back out the bump
        NSLog(@"WARNING: Couldn't save chat picture message: %@", error);
        return NO;
    }
    return YES;
}


- (void) postStatusChanged {
    NSLog(@"STATUS: %@: unread = %u, modDate = %@ by %@",
          self, _unreadMessageCount, _modDate, _lastSenderID);
    [[NSNotificationCenter defaultCenter] postNotificationName: kChatRoomStatusChangedNotification
                                                        object: self];
    [self saveLocalState];
}


- (void) setMessageCount: (unsigned)messageCount
                 modDate: (NSDate*)modDate
              lastSender: (NSString*)lastSender
{
    bool changed = false;
    int delta = ((int)messageCount - (int)_messageCount);
    if (delta != 0) {
        _messageCount = messageCount;
        self.unreadMessageCount += delta;
        changed = true;
    }
    if (![modDate isEqualToDate: _modDate]) {
        self.modDate = modDate;
        changed = true;
    }
    _lastSenderID = lastSender;
    if (changed)
        [self postStatusChanged];
}


- (void) markAsRead {
    if (_unreadMessageCount == 0)
        return;
    NSLog(@"MARK READ: %@", self);
    self.unreadMessageCount = 0;
    [self postStatusChanged];
}


- (NSString*) localStateDocID {
    return [@"chatState-" stringByAppendingString: self.document.documentID];
}


- (void) saveLocalState {
    unsigned readCount = _messageCount - _unreadMessageCount;
    NSError* error;
    if (![self.database putLocalDocument: @{@"readCount": @(readCount)}
                             withID: self.localStateDocID
                              error: &error])
        NSLog(@"Warning: Couldn't save local doc: %@", error);
}


- (void) loadLocalState {
    if (self.document) {
        NSDictionary* state = [self.database existingLocalDocumentWithID: self.localStateDocID];
        _messageCount = [state[@"readCount"] unsignedIntValue];
    }
}


@end
