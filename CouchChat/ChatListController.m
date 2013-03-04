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
#import <CouchbaseLite/CouchbaseLite.h>


@implementation ChatListController
{
    IBOutlet UITableView* _table;
    IBOutlet CBLUITableSource* _dataSource;
    UIBarButtonItem* _newChatButton;
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
							
- (void)viewDidLoad {
    [super viewDidLoad];

    _dataSource.query = _chatStore.allChatsQuery;
    _dataSource.deletionAllowed = YES;

    self.title = @"Chats";
    _newChatButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                   target:self
                                                                   action:@selector(newChat:)];
    self.navigationItem.rightBarButtonItem = _newChatButton;

    [self selectChat: _chatController.chatRoom];
}


- (void)viewWillAppear:(BOOL)animated {
    //FIX: This isn't good enough in landscape mode, where the view is always visible.
    [self updateCells];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        NSIndexPath* sel = _table.indexPathForSelectedRow;
        if (sel)
            [_table deselectRowAtIndexPath: sel animated: NO];
    }
}


#pragma mark - ACTIONS:


- (void) createChatWithTitle: (NSString*)title {
    ChatRoom* chat = [_chatStore newChatWithTitle: title];
    NSError* error;
    if (![chat save: &error]) {
        [gAppDelegate showAlert: @"Couldn't create chat" error: error fatal: NO];
    }

    _chatController.chatRoom = chat;
}


- (IBAction) newChat: (id)sender {
    NSString* title = [NSString stringWithFormat: @"Create A New Chat"];
    UIAlertView* alert;
    if (!_chatStore.username) {
        alert = [[UIAlertView alloc] initWithTitle: title
                                           message: @"Please log in and sync first."
                                          delegate: self
                                 cancelButtonTitle: @"Login"
                                 otherButtonTitles: nil];
    } else {
        //FIX: This is an awful UI.
        alert = [[UIAlertView alloc] initWithTitle: title
                                           message: @"What's the title of the new chat?"
                                          delegate: self
                                 cancelButtonTitle: @"Cancel"
                                 otherButtonTitles: @"Create", nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField* titleField = [alert textFieldAtIndex: 0];
        titleField.autocapitalizationType = UITextAutocapitalizationTypeWords;
        titleField.returnKeyType = UIReturnKeyDone;
    }
    [alert show];
}

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alert {
    return [alert textFieldAtIndex: 0].text.length > 0;
}

- (void)alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (_chatStore.username) {
        if (buttonIndex > 0) {
            NSString* title = [alert textFieldAtIndex: 0].text;
            if (title.length > 0)
                [self createChatWithTitle: title];
        }
    } else {
        [_chatController configureSync];
    }
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
    NSIndexPath* path = chat ? [_dataSource indexPathForDocument: chat.document] : nil;
    if (!path)
        return false;
    [_dataSource.tableView selectRowAtIndexPath: path
                                       animated: NO
                                 scrollPosition: UITableViewScrollPositionMiddle];
    [self showChat: chat];
    return true;
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString: @"chatController.chatRoom"]) {
        [self selectChat: _chatController.chatRoom];
    }
}


#pragma mark - TABLE DELEGATE:


- (ChatRoom*) chatForRow: (CBLQueryRow*)row {
    return [ChatRoom modelForDocument: row.document];
}

- (ChatRoom*) chatForPath: (NSIndexPath*)indexPath {
    CBLDocument* doc = [_dataSource documentAtIndexPath: indexPath];
    return [ChatRoom modelForDocument: doc];
}



- (void)couchTableSource:(CBLUITableSource*)source
             willUseCell:(UITableViewCell*)cell
                  forRow:(CBLQueryRow*)row
{
    ChatRoom* chat = [self chatForRow: row];
    cell.textLabel.text = chat.title;
    cell.imageView.image = [UIImage imageNamed: @"ChatIcon"];
    [cell.imageView sizeToFit];
    [self updateCell: cell forChat: chat];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self showChat: [self chatForPath: indexPath]];
}


- (void) updateCells {
    for (UITableViewCell* cell in _table.visibleCells) {
        ChatRoom* chat = [self chatForPath: [_table indexPathForCell: cell]];
        [self updateCell: cell forChat: chat];
    }
}


- (void) updateCell: (UITableViewCell*)cell forChat: (ChatRoom*)chat {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    /*
    UIImageView* accessory = (UIImageView*)cell.accessoryView;
    if (!chat.draft) {
        accessory.image = nil;
    } else if (accessory) {
        accessory.image = [UIImage imageNamed: @"EditedIcon"];
    } else {
        UIImage* editedImage = [UIImage imageNamed: @"EditedIcon"];
        cell.accessoryView = [[UIImageView alloc] initWithImage: editedImage];
    }
     */
}


@end
