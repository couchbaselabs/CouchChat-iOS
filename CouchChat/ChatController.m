//
//  ChatController.m
//  CouchChat
//
//  Created by Jens Alfke on 2/13/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "ChatController.h"
#import "ChatRoom.h"
#import "ChatStore.h"
#import "UserProfile.h"
#import "UserPickerController.h"
#import "BTVBubbleTableView.h"
#import <CouchbaseLite/CBLJSON.h>


#define kMaxPicturePixelDimensions 800


@interface ChatController () <BTVBubbleTableViewDataSource, UIImagePickerControllerDelegate,
                              UIPopoverControllerDelegate, UINavigationControllerDelegate,
                              UserPickerControllerDelegate>
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@end


@implementation ChatController
{
    NSString* _username;
    NSArray* _rows;
    ChatStore* _chatStore;
    ChatRoom* _chatRoom;
    CBLLiveQuery* _query;
    IBOutlet BTVBubbleTableView* _bubbles;
    IBOutlet UITextField* _inputLine;
    UIButton* _pickerButton;
    UIPopoverController* _imagePickerPopover;
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _chatStore = [ChatStore sharedInstance];
        _username = _chatStore.username;
    }
    return self;
}


- (void)dealloc {
    [_query removeObserver: self forKeyPath: @"rows"];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardWillShow:)
                                                 name: UIKeyboardWillShowNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardWillHide:)
                                                 name: UIKeyboardWillHideNotification
                                               object: nil];

    UIButton* inviteButton = [UIButton buttonWithType: UIButtonTypeContactAdd];
    [inviteButton addTarget: self action: @selector(addUsers)
           forControlEvents: UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView: inviteButton];

    UIImage* pattern = [UIImage imageNamed: @"double_lined.png"];
    self.view.backgroundColor = [UIColor colorWithPatternImage: pattern];

    _pickerButton = [UIButton buttonWithType: UIButtonTypeCustom];
    [_pickerButton setImage: [UIImage imageNamed: @"Camera.png"] forState: UIControlStateNormal];
    _pickerButton.frame = CGRectMake(0, 0, 24, 24);
    [_pickerButton addTarget: self action: @selector(addPicture:)
            forControlEvents: UIControlEventTouchUpInside];
    _inputLine.rightView = _pickerButton;
    _inputLine.rightViewMode = UITextFieldViewModeAlways;

    _bubbles.showAvatars = YES;
    [_bubbles reloadData];
    [self scrollToBottom];

    UIGestureRecognizer* g = [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(bubblesTouched)];
    [_bubbles addGestureRecognizer: g];
}


- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    [_chatRoom markAsRead];
}


- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    // Bad Stuff happens if the keyboard remains visible while this view is hidden.
    [_inputLine resignFirstResponder];
}


- (void)setChatRoom:(ChatRoom*)newChatRoom {
    if (_chatRoom != newChatRoom) {
        _chatRoom = newChatRoom;

        [_query removeObserver: self forKeyPath: @"rows"];
        _query = _chatRoom.chatMessagesQuery.asLiveQuery;
        [_query addObserver: self forKeyPath: @"rows" options: 0 context: NULL];
        [self reloadFromQuery];

        self.title = newChatRoom ? newChatRoom.displayName : @"";

        if (self.view.superview != nil)
            [_chatRoom markAsRead];
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }        
}


- (IBAction) configureSync {
    // TODO
}
							

#pragma mark - MESSAGE DISPLAY:


- (void) reloadFromQuery {
    CBLQueryEnumerator* rowEnum = _query.rows;
    if (rowEnum) {
        _rows = rowEnum.allObjects;
        NSLog(@"ChatController: Showing %u messages", _rows.count);
        [_bubbles reloadData];
        [self scrollToBottom];
    }
}


- (void) scrollToBottom {
    CGRect bottom = {{0, 0}, {1, 1}};
    bottom.origin.y =_bubbles.contentSize.height - 1;
    [_bubbles scrollRectToVisible: bottom animated: YES];
}


- (void) observeValueForKeyPath: (NSString*)keyPath ofObject: (id)object
                         change: (NSDictionary*)change context: (void*)context
{
    if (object == _query)
        [self reloadFromQuery];
}


- (NSInteger) numberOfRowsForBubbleTable: (BTVBubbleTableView *)tableView {
    return _rows.count;
}

- (BTVBubbleData*) bubbleTableView: (BTVBubbleTableView*)tableView dataForRow: (NSInteger)row {
    // See map block definition in ChatStore.m
    CBLQueryRow* r = _rows[row];
    NSArray* key = r.key;
    NSArray* value = r.value;
    NSString* sender = value[0];
    NSString* text = value[1];
    bool hasPicture = [value[2] boolValue];
    bool isAnnouncement = [value[3] boolValue];
    NSDate* date = [CBLJSON dateWithJSONObject: key[1]];
    BOOL mine = [sender isEqual: _username];

    UIImage* image = nil;
    if (hasPicture) {
        CBLAttachment* att = [r.document.currentRevision attachmentNamed: @"picture"];
        NSData* imageData = att.content;
        if (imageData)
            image = [[UIImage alloc] initWithData: imageData];
    }

    BTVBubbleData* bubble;
    if (image) {
        bubble = [BTVBubbleData dataWithImage: image
                                      date: date
                                      type: (mine ? BubbleTypeMine : BubbleTypeSomeoneElse)];
        //FIX: If doc has markdown as well as image, the text won't be shown!
    } else {
        //FIX: Render the markdown
        bubble = [BTVBubbleData dataWithText: text
                                     date: date
                                     type: (mine ? BubbleTypeMine : BubbleTypeSomeoneElse)];
    }

    if (isAnnouncement)
        bubble.hasBubble = bubble.hasAvatar = false;
    else
        bubble.avatar = [_chatStore pictureForUsername: sender];

    return bubble;
}


- (void) bubblesTouched {
    [_inputLine resignFirstResponder];
}


#pragma mark - INPUT LINE:


- (void) setFrameMaxY: (CGFloat)maxY {
    CGRect frame = self.view.frame;
    frame.size.height = maxY - frame.origin.y;
    self.view.frame = frame;
}


- (void) keyboardWillShow: (NSNotification*)n {
    CGRect kbdFrame = [(NSValue*)n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    kbdFrame = [self.view.window convertRect: kbdFrame fromWindow: nil];
    kbdFrame = [self.view.superview convertRect: kbdFrame fromView: nil];
    [self setFrameMaxY: kbdFrame.origin.y];
}


- (void) keyboardWillHide: (NSNotification*)n {
    [self setFrameMaxY: CGRectGetMaxY(self.view.superview.bounds)];
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSString* message = _inputLine.text;
    if (message.length == 0)
        return NO;

    if (![_chatRoom addChatMessage: message announcement: false picture: nil])
        return NO;
    _inputLine.text = @"";
    return YES;
}


#pragma mark - IMAGE PICKER:


- (IBAction) addPicture:( id)sender {
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        NSString* message = @"Take a photo with the camera, or choose an existing photo?";
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle: @"Add Picture"
                                                        message: message
                                                       delegate: self
                                              cancelButtonTitle: @"Cancel"
                                              otherButtonTitles: @"Use Camera", @"Choose Photo",
                              nil];
        [alert show];
    } else {
        [self pickPictureFromSource: UIImagePickerControllerSourceTypePhotoLibrary];
    }
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 1:
            [self pickPictureFromSource: UIImagePickerControllerSourceTypeCamera];
            break;
        case 2:
            [self pickPictureFromSource: UIImagePickerControllerSourceTypePhotoLibrary];
            break;
    }
}


- (void) pickPictureFromSource: (UIImagePickerControllerSourceType)source {
    if (![UIImagePickerController isSourceTypeAvailable: source])
        return;
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
	imagePicker.delegate = self;
    //imagePicker.allowsEditing = YES;  // unfortunately this forces square crop & small dimensions
    imagePicker.sourceType = source;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone
            || source == UIImagePickerControllerSourceTypeCamera) {
        [self presentViewController:imagePicker animated:YES completion: nil];
    } else {
        _imagePickerPopover = [[UIPopoverController alloc] initWithContentViewController: imagePicker];
        _imagePickerPopover.delegate = self;
        [_imagePickerPopover presentPopoverFromRect: [_pickerButton bounds]
                                             inView: _pickerButton
                           permittedArrowDirections: UIPopoverArrowDirectionAny
                                           animated: YES];
    }
}


- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage* picture = info[UIImagePickerControllerEditedImage];
    if (!picture)
        picture = info[UIImagePickerControllerOriginalImage];
    [self closeImagePicker];

    if (picture) {
        picture = [self scaleImage: picture maxPixels: kMaxPicturePixelDimensions];
        [_chatRoom addChatMessage: nil
                     announcement: false
                          picture: picture];
    }
}


- (void) closeImagePicker {
    if (_imagePickerPopover)
        [_imagePickerPopover dismissPopoverAnimated: YES];
    else
        [self dismissViewControllerAnimated: YES completion: nil];
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self closeImagePicker];
}


- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    _imagePickerPopover = nil;
}


- (UIImage*) scaleImage: (UIImage*)image maxPixels: (CGFloat)maxPixels {
    // Compute the pixel dimensions:
    double scale = image.scale;
    CGSize pointSize = image.size;
    double shrinkFactor = MIN(maxPixels / (pointSize.width * scale),
                              maxPixels / (pointSize.height * scale));
    if (shrinkFactor >= 1.0)
        return image;  // no shrinking needed

    scale *= shrinkFactor;
    if (scale < 1.0) {
        // If scale would drop below 72dpi, we do need to reduce the pixel count.
        pointSize.width *= scale;
        pointSize.height *= scale;
        scale = 1.0;
    }

    UIGraphicsBeginImageContextWithOptions(pointSize, YES, scale);
    CGRect imageRect = CGRectMake(0.0, 0.0, pointSize.width, pointSize.height);
    [image drawInRect:imageRect];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}


#pragma mark - SPLIT VIEW:


- (void)splitViewController:(UISplitViewController *)splitController
     willHideViewController:(UIViewController *)viewController
          withBarButtonItem:(UIBarButtonItem *)barButtonItem
       forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Chats", @"Chats");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController
     willShowViewController:(UIViewController *)viewController
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}


#pragma mark - ADDING USERS:


- (IBAction) addUsers {
    UserPickerController *picker = [[UserPickerController alloc] initWithUsers: _chatStore.allOtherUsers
                                                                      delegate: self];
    for (UserProfile* user in _chatRoom.allMemberProfiles)
        [picker selectContact: user];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: @"Cancel" style:UIBarButtonItemStylePlain target:nil action:NULL];
    picker.navigationItem.rightBarButtonItem.title = @"Done";
    picker.title = @"Edit Member List";
    [self.navigationController pushViewController: picker animated: YES];
}


- (void) userPickerController: (UserPickerController*)controller
                  pickedUsers: (NSArray*)users
{
    self.navigationItem.backBarButtonItem = nil;
    [self.navigationController popToViewController: self animated: NO];
    if (users == nil )
        return;

    users = [users arrayByAddingObject: _chatStore.user];

    // Post invite/kick messages:
    NSSet* newMembers = [NSSet setWithArray: users];
    NSSet* oldMembers = _chatRoom.allMemberProfiles.set;
    [self addMessageForChange: @"invited" forUsers: newMembers notUsers: oldMembers];
    [self addMessageForChange: @"removed" forUsers: oldMembers notUsers: newMembers];

    // Update the membership:
    NSMutableArray* memberNames = [NSMutableArray array];
    for (UserProfile* user in users)
        [memberNames addObject: user.username];
    //TODO: This makes everyone an owner. Fix this if we add support for non-owner members.
    _chatRoom.owners = memberNames;
    _chatRoom.members = [NSArray array];

    // Changing membership may change the display name of this chat room:
    self.title = _chatRoom.displayName;
}


- (void) addMessageForChange: (NSString*)change forUsers: (NSSet*)users notUsers: (NSSet*)notUsers {
    NSMutableSet* diff = [users mutableCopy];
    [diff minusSet: notUsers];
    if (diff.count == 0)
        return;
    NSString* message = [NSString stringWithFormat: @"%@ %@ %@.",
                         _chatStore.user.displayName, change, [UserProfile listOfNames: diff]];
    [_chatRoom addChatMessage: message announcement: true picture: nil];
}


@end
