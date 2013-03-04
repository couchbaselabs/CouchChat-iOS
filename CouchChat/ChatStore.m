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


static ChatStore* sInstance;


@implementation ChatStore
{
    CBLView* _usersView;
}


@synthesize username=_username;


- (id) initWithDatabase: (CBLDatabase*)database {
    self = [super init];
    if (self) {
        NSAssert(!sInstance, @"Cannot create more than one ChatStore");
        sInstance = self;
        _database = database;
        _username = [[NSUserDefaults standardUserDefaults] stringForKey: @"UserName"];
        
        [_database.modelFactory registerClass: [ChatRoom class] forDocumentType: @"chat"];
        [_database.modelFactory registerClass: [UserProfile class] forDocumentType: @"profile"];

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
                NSString* channelID = doc[@"channel_id"];
                if (!channelID)
                    return;
                bool hasAttachments = [doc[@"_attachments"] count] > 0;
                bool isAnnouncement = [doc[@"style"] isEqualToString: @"announcement"];
                emit(@[channelID, doc[@"created_at"]],
                     @[doc[@"author"], markdown, @(hasAttachments), @(isAnnouncement)]);
            }
        }) version: @"4"];

        // View for getting user profiles by name
        _usersView = [_database viewNamed: @"usersByName"];
        [_usersView setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqualToString: @"profile"]) {
                NSString* name = doc[@"nick"] ?: [UserProfile usernameFromDocID: doc[@"_id"]];
                if (name)
                    emit(name.lowercaseString, name);
            }
        }) version: @"3"];
        _allChatsQuery = [[view query] asLiveQuery];

#if 0
        [self createFakeUsers];
#endif

    }
    return self;
}


+ (ChatStore*) sharedInstance {
    return sInstance;
}


#pragma mark - CHATS:


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
    if (profile)
        return profile.picture;
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
    return [_usersView query];
}

- (NSArray*) allOtherUsers {
    NSMutableArray* users = [NSMutableArray array];
    for (CBLQueryRow* row in self.allUsersQuery.rows.allObjects) {
        UserProfile* user = [UserProfile modelForDocument: row.document];
        if (![user.username isEqualToString: _username])
            [users addObject: user];
    }
    return users;
}



@end
