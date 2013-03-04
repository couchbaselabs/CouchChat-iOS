//
//  ChatListController.h
//  CouchChat
//
//  Created by Jens Alfke on 2/13/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CouchbaseLite/CBLUITableSource.h>
@class ChatController, ChatStore, ChatRoom;


@interface ChatListController : UIViewController <CBLUITableDelegate>

@property (strong, nonatomic) ChatController *chatController;

@property (readonly, nonatomic) ChatStore* chatStore;
@property (strong, nonatomic) ChatRoom* chat;

- (void) createChatWithTitle: (NSString*)title
                  otherUsers: (NSArray*)otherUsers;

@end
