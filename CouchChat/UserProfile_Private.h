//
//  UserProfile_Private.h
//  CouchChat
//
//  Created by Jens Alfke on 3/1/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "UserProfile.h"

@interface UserProfile ()
- (void) setName: (NSString*)name nick: (NSString*)nick;
- (void) setPicture:(UIImage *)picture;
@end
