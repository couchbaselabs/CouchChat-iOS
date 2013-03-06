//
//  ChatController.h
//  CouchChat
//
//  Created by Jens Alfke on 2/13/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <UIKit/UIKit.h>
@class ChatRoom;

@interface ChatController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) ChatRoom* chatRoom;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

- (IBAction) addPicture:(id)sender;
- (IBAction) configureSync;
- (IBAction) addUsers;

@end
