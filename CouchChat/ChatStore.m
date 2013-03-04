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
                bool hasAttachments = [doc[@"_attachments"] count] > 0;
                emit(@[doc[@"channel_id"], doc[@"created_at"]],
                     @[doc[@"author"], markdown, @(hasAttachments)]);
            }
        }) version: @"3"];

        // View for getting user profiles by name
        _usersView = [_database viewNamed: @"usersByName"];
        [view setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqualToString: @"user"]) {
                NSString* name = doc[@"nick"] ?: doc[@"username"];
                if (name)
                    emit(name.lowercaseString, name);
            }
        }) version: @"1"];
        _allChatsQuery = [[view query] asLiveQuery];

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



@end
