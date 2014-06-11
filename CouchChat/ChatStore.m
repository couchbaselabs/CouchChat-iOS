//
//  ChatStore.m
//  CouchChat
//
//  Created by Jens Alfke on 12/18/12.
//  Copyright (c) 2012 Couchbase. All rights reserved.
//

#import "ChatStore.h"
#import "ChatRoom.h"
#import "UserProfile_Private.h"
#import <CouchbaseLite/CBLModelFactory.h>
#import <CouchbaseLite/CBLJSON.h>


static ChatStore* sInstance;


@interface ChatStore ()
@property (readwrite, copy) NSArray* allChats;
@end


@implementation ChatStore
{
    CBLView* _usersView;
    CBLLiveQuery* _chatModDatesQuery;
}


@synthesize username=_username, allChats=_allChats;


- (id) initWithDatabase: (CBLDatabase*)database {
    self = [super init];
    if (self) {
        NSAssert(!sInstance, @"Cannot create more than one ChatStore");
        sInstance = self;
        _database = database;
        _username = [[NSUserDefaults standardUserDefaults] stringForKey: @"UserName"];
        
        [_database.modelFactory registerClass: [ChatRoom class] forDocumentType: @"room"];
        [_database.modelFactory registerClass: [UserProfile class] forDocumentType: @"profile"];

        // Map function for getting chat messages for each chat, sorted by date
        CBLView* view = [_database viewNamed: @"chatMessages"];
        [view setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqualToString: @"chat"]) {
                NSString* markdown = doc[@"markdown"] ?: @"";
                NSString* channelID = doc[@"channel_id"];
                if (!channelID)
                    return;
                bool hasAttachments = [doc[@"_attachments"] count] > 0;
                bool isAnnouncement = [doc[@"style"] isEqualToString: @"announcement"];
                emit(@[channelID, doc[@"created_at"]],
                     @[doc[@"author"], markdown, @(hasAttachments), @(isAnnouncement)]);
            }
        }) reduceBlock: REDUCEBLOCK({
            // Reduce function returns [mod_date, message_count]
            NSString* maxDate = [NSDate distantPast];
            NSUInteger count = 0;
            NSString* lastSender = @"";
            if (rereduce) {
                for (NSArray* reducedItem in values) {
                    count += [reducedItem[1] unsignedIntValue];
                    NSString* date = reducedItem[0];
                    if ([date compare: maxDate] > 0) {
                        maxDate = date;
                        lastSender = reducedItem[2];
                    }
                }
            } else {
                maxDate = [keys.lastObject objectAtIndex: 1]; // since keys are in order
                lastSender = [values.lastObject objectAtIndex: 0];
                count = values.count;
            }
            return (@[maxDate, @(count), lastSender]);
        }) version: @"7"];

        _chatModDatesQuery = [[view createQuery] asLiveQuery];
        _chatModDatesQuery.groupLevel = 1;
        [_chatModDatesQuery addObserver: self forKeyPath: @"rows"
                                options: NSKeyValueObservingOptionInitial context: NULL];

        // View for getting user profiles by name
        _usersView = [_database viewNamed: @"usersByName"];
        [_usersView setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqualToString: @"profile"]) {
                NSString* name = doc[@"nick"] ?: [UserProfile usernameFromDocID: doc[@"_id"]];
                if (name)
                    emit(name.lowercaseString, name);
            }
        }) version: @"3"];

#if 0
        [self createFakeUsers];
#endif

    }
    return self;
}


- (void)dealloc
{
    [_chatModDatesQuery removeObserver: self forKeyPath: @"rows"];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _chatModDatesQuery) {
        [self refreshChatList];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


+ (ChatStore*) sharedInstance {
    return sInstance;
}


#pragma mark - CHATS:


- (ChatRoom*) newChatWithTitle: (NSString*)title {
    return [[ChatRoom alloc] initNewWithTitle: title inChatStore: self];
}


- (void) refreshChatList {
    NSMutableArray* chats = [NSMutableArray array];
    for (CBLQueryRow* row in _chatModDatesQuery.rows) {
        CBLDocument* document = [_database documentWithID: row.key0];
        ChatRoom* chat = [ChatRoom modelForDocument: document];
        if (chat.isMember) {
            [chats addObject: chat];
            NSArray* value = row.value;
            NSDate* modDate = [CBLJSON dateWithJSONObject: value[0]];
            NSUInteger count = [value[1] unsignedIntegerValue];
            NSString* lastSender = value[2];
            [chat setMessageCount: count modDate: modDate lastSender: lastSender];
        }
    }
    [chats sortUsingComparator: ^NSComparisonResult(ChatRoom *chat1, ChatRoom *chat2) {
        return [chat2.modDate compare: chat1.modDate];  // descending order!
    }];
    
    if (![chats isEqual: _allChats]) {
        self.allChats = chats;
    }
}


#pragma mark - USERS:


#if 0
- (void) createFakeUsers {
    UserProfile* profile = [self profileWithUsername: @"foo@example.com"];
    if (!profile) {
        profile = [UserProfile createInDatabase: _database
                                   withUsername: @"foo@example.com"];
        [profile setName: @"Foo Bar" nick: @"foobar"];
    }
    profile = [self profileWithUsername: @"pupshaw@example.com"];
    if (!profile) {
        profile = [UserProfile createInDatabase: _database
                                   withUsername: @"pupshaw@example.com"];
        [profile setName: @"Pupshaw" nick: nil];
    }
}
#endif


- (void) setUsername:(NSString *)username {
    if (![username isEqualToString: _username]) {
        NSLog(@"Setting chat username to '%@'", username);
        _username = [username copy];
        [[NSUserDefaults standardUserDefaults] setObject: username forKey: @"UserName"];

        UserProfile* myProfile = [self profileWithUsername: _username];
        if (!myProfile) {
            myProfile = [UserProfile createInDatabase: _database
                                         withUsername: _username];
            NSLog(@"Created user profile %@", myProfile);
        }
    }
}


- (UserProfile*) user {
    if (!_username)
        return nil;
    UserProfile* user = [self profileWithUsername: _username];
    if (!user) {
        user = [UserProfile createInDatabase: _database
                                withUsername: _username];
    }
    return user;
}


- (UserProfile*) profileWithUsername: (NSString*)username {
    NSString* docID = [UserProfile docIDForUsername: username];
    CBLDocument* doc = [self.database documentWithID: docID];
    if (!doc.currentRevisionID)
        return nil;
    return [UserProfile modelForDocument: doc];
}


- (UIImage*) pictureForUsername: (NSString*)username {
    UserProfile* profile = [self profileWithUsername: username];
    if (profile) {
        UIImage* picture = profile.picture;
        if (picture)
            return picture;
    }
    return [UserProfile loadGravatarForEmail: username];
}


- (void) setMyProfileName: (NSString*)name nick: (NSString*)nick {
    UserProfile* myProfile = [self profileWithUsername: self.username];
    [myProfile setName: name nick: nick];
}

- (void) setMyProfilePicture:(UIImage *)picture {
    UserProfile* myProfile = [self profileWithUsername: self.username];
    [myProfile setPicture: picture];
}


- (CBLQuery*) allUsersQuery {
    return [_usersView createQuery];
}

- (NSArray*) allOtherUsers {
    NSMutableArray* users = [NSMutableArray array];
    for (CBLQueryRow* row in [self.allUsersQuery run: NULL].allObjects) {
        UserProfile* user = [UserProfile modelForDocument: row.document];
        if (![user.username isEqualToString: _username])
            [users addObject: user];
    }
    return users;
}



@end
