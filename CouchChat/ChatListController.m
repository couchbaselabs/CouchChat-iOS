//
//  ChatListController.m
//  CouchChat
//
//  Created by Jens Alfke on 2/13/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "ChatListController.h"
#import "ChatController.h"
#import "AppDelegate.h"
#import "ChatStore.h"
#import "ChatRoom.h"
#import "UserProfile.h"
#import "UserPickerController.h"
#import <CouchbaseLite/CouchbaseLite.h>


@interface ChatListController () <UserPickerControllerDelegate>
@end


@implementation ChatListController
{
    IBOutlet UITableView* _table;
    UIBarButtonItem* _newChatButton;
    NSArray* _chats;
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName: nibNameOrNil bundle: nibBundleOrNil];
    if (self) {
        _chatStore = [ChatStore sharedInstance];
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
        self.restorationIdentifier = @"ChatListController";
    }
    return self;
}
							
- (void) viewDidLoad {
    [super viewDidLoad];

    self.title = @"Chats";
    _newChatButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                   target:self
                                                                   action:@selector(newChat:)];
    self.navigationItem.rightBarButtonItem = _newChatButton;

    //FIX: This is a workaround until chats can persistently store their unread counts. On launch,
    // reset every chat's unread count to 0. That way, only messages received after the app
    // launches will appear as unread, instead of _all_ messages ever received.
    for (ChatRoom* chat in _chatStore.allChats)
        [chat markAsRead];

    [_chatStore addObserver: self forKeyPath: @"allChats"
                    options: NSKeyValueObservingOptionInitial context: NULL];
    // Use NSNotification to listen for status changes, because otherwise we'd have to observe
    // each item of _chats, but NSArray doesn't support KVO :(
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(chatStatusChanged:)
                                                 name: kChatRoomStatusChangedNotification
                                               object: nil];
    [self selectChat: _chatController.chatRoom];
}


- (void) viewWillAppear: (BOOL)animated {
    [super viewWillAppear: animated];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        NSIndexPath* sel = _table.indexPathForSelectedRow;
        if (sel)
            [_table deselectRowAtIndexPath: sel animated: NO];
    }
}

- (void)dealloc {
    [_chatStore removeObserver: self forKeyPath: @"allChats"];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


#pragma mark - NEW CHAT:


- (IBAction) newChat: (id)sender {
    if (!_chatStore.username) {
        UIAlertView* alert;
        alert = [[UIAlertView alloc] initWithTitle: @"Not Logged In"
                                           message: @"Please log in and sync first."
                                          delegate: self
                                 cancelButtonTitle: @"Login"
                                 otherButtonTitles: nil];
        [alert show];
        return;
    }

    NSArray* users = _chatStore.allOtherUsers;
    UserPickerController *picker = [[UserPickerController alloc] initWithUsers: users
                                                                      delegate: self];
    [self.navigationController pushViewController: picker animated: YES];
}

- (void)alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex >= 0)
        [_chatController configureSync];
}

- (void) userPickerController: (UserPickerController*)controller
                  pickedUsers: (NSArray*)users
{
    [self.navigationController popToViewController: self animated: NO];
    if (users.count > 0)
        [self createChatWithTitle: nil otherUsers: users];
}


- (void) createChatWithTitle: (NSString*)title otherUsers: (NSArray*)otherUsers {
    if (title.length == 0) {
        NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
        fmt.dateStyle = NSDateFormatterShortStyle;
        fmt.timeStyle = NSDateFormatterShortStyle;
        title = [fmt stringFromDate: [NSDate date]];
    }

    ChatRoom* chat = [_chatStore newChatWithTitle: title];

    NSMutableArray* allUsernames = [NSMutableArray arrayWithObject: _chatStore.username];
    NSMutableArray* otherDisplaynames = [NSMutableArray array];
    for (UserProfile* user in otherUsers) {
        [allUsernames addObject: user.username];
        [otherDisplaynames addObject: user.displayName];
    }
    chat.owners = allUsernames;
    
    NSError* error;
    if (![chat save: &error]) {
        [gAppDelegate showAlert: @"Couldn't create chat" error: error fatal: NO];
    }

    NSString* msg = [NSString stringWithFormat: @"%@ started the chat, inviting %@.",
                     _chatStore.user.displayName,
                     [UserProfile listOfNames: otherUsers]];
    [chat addChatMessage: msg announcement: true picture: nil];

    [self showChat: chat];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == _chatStore) {
        _chats = _chatStore.allChats;
        [_table reloadData];
    } else if ([keyPath isEqualToString: @"chatController.chatRoom"]) {
        [self selectChat: _chatController.chatRoom];
    }
}


- (ChatRoom*) chatForPath: (NSIndexPath*)indexPath {
    return _chats[indexPath.row];
}


- (NSIndexPath*) pathForChat: (ChatRoom*)chat {
    NSUInteger row = [_chats indexOfObjectIdenticalTo: chat];
    if (row == NSNotFound)
        return nil;
    return [NSIndexPath indexPathForRow: row inSection: 0];
}


#pragma mark - SELECTION:


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self showChat: [self chatForPath: indexPath]];
}


- (void) showChat: (ChatRoom*)chat {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
	    if (!_chatController) {
	        self.chatController = [[ChatController alloc] initWithNibName:@"ChatController_iPhone"
                                                                   bundle:nil];
        }
        _chatController.chatRoom = chat;
        [self.navigationController pushViewController: _chatController animated: YES];
    } else {
        if (chat != _chatController.chatRoom)
            _chatController.chatRoom = chat;
    }
}


- (bool) selectChat: (ChatRoom*)chat {
    NSIndexPath* path = [self pathForChat: chat];
    if (!path)
        return false;
    [_table selectRowAtIndexPath: path
                        animated: NO
                  scrollPosition: UITableViewScrollPositionMiddle];
    [self showChat: chat];
    return true;
}


#pragma mark - TABLE DISPLAY:


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _chats.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ChatRoom* chat = [self chatForPath: indexPath];

    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier: @"Chat"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle
                                      reuseIdentifier: @"Chat"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    [self updateCell: cell forChat: chat];
    return cell;
}



- (void) chatStatusChanged: (NSNotification*)n {
    ChatRoom* chat = n.object;
    NSIndexPath* path = [self pathForChat: chat];
    if (!path)
        return;
    [_table reloadData];
}


- (void) updateCells {
    for (UITableViewCell* cell in _table.visibleCells) {
        ChatRoom* chat = [self chatForPath: [_table indexPathForCell: cell]];
        [self updateCell: cell forChat: chat];
    }
}


- (void) updateCell: (UITableViewCell*)cell forChat: (ChatRoom*)chat {
    static NSDateFormatter* sDateFormat;
    if (!sDateFormat) {
        sDateFormat = [[NSDateFormatter alloc] init];
        sDateFormat.dateStyle = NSDateFormatterMediumStyle;
        sDateFormat.timeStyle = NSDateFormatterShortStyle;
    }

    cell.textLabel.text = chat.displayName;

    NSString* detail = nil;
    unsigned unread = chat.unreadMessageCount;
    UserProfile* lastSender = chat.lastSender;
    if (unread)
        detail = [NSString stringWithFormat: @"%u unread; latest by %@",
                  unread, lastSender.displayName];
    else
        detail = [NSString stringWithFormat: @"last updated %@",
                  [sDateFormat stringFromDate: chat.modDate]];
    cell.detailTextLabel.text = detail;

    UIImage *lastSenderImage = nil;
    if (unread > 0 && lastSender)
            lastSenderImage = [_chatStore pictureForUsername: lastSender.username];

    cell.imageView.image = lastSenderImage ?: [UIImage imageNamed: @"ChatIcon"];
}


- (void)tableView:(UITableView *)tableView
        willDisplayCell:(UITableViewCell *)cell
        forRowAtIndexPath:(NSIndexPath *)indexPath
{
    ChatRoom* chat = [self chatForPath: indexPath];
    unsigned unread = chat.unreadMessageCount;
    cell.backgroundColor = unread ? [UIColor yellowColor] : [UIColor clearColor];
}


#pragma mark - EDITING:


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}


- (void)tableView:(UITableView *)tableView
        commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
        forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete)
        return;

    ChatRoom* chat = [self chatForPath: indexPath];
    if (!chat.isMember)
        return;

    // Delete the row from the table data source.
    [_table deleteRowsAtIndexPaths: @[indexPath] withRowAnimation: UITableViewRowAnimationFade];

    NSString* msg = [NSString stringWithFormat: @"%@ left the chat.",
                     _chatStore.user.displayName];
    [chat removeMember: _chatStore.user withMessage: msg];
}


@end
