//
//  LoginController.m
//  TouchWiki
//
//  Created by Jens Alfke on 1/3/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "LoginController.h"
#import "SyncManager.h"


@implementation LoginController
{
    NSString* _username;
    NSURL* _url;
}


- (id) initWithURL: (NSURL*)url username: (NSString*)username {
    self = [super init];
    if (self) {
        _url = url;
        _username = username;
    }
    return self;
}


- (void) run {
    NSString* title = [NSString stringWithFormat: @"Log into %@", _url.host];
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: nil
                                                   delegate: self
                                          cancelButtonTitle: @"Cancel"
                                          otherButtonTitles: @"OK", nil];
    alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    if (_username)
        [alert textFieldAtIndex: 0].text = _username;
    [alert show];
}


- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alert {
    return [alert textFieldAtIndex: 0].text.length > 0
        && [alert textFieldAtIndex: 1].text.length > 0;
}


- (void)alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
            [_delegate loginCanceled];
            break;
        case 1:
            [_delegate setUsername: [alert textFieldAtIndex: 0].text
                          password: [alert textFieldAtIndex: 1].text];
            break;
    }
}


@end
