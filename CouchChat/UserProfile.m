//
//  UserProfile.m
//  CouchChat
//
//  Created by Jens Alfke on 2/15/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "UserProfile.h"
#import "ChatStore.h"
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>


@implementation UserProfile
{
    bool _checkedPicture;
    __weak UIImage* _picture;
}


+ (NSString*) docIDForUsername: (NSString*)username {
    return [@"profile:" stringByAppendingString: username];
}

+ (NSString*) usernameFromDocID: (NSString*)docID {
    return [docID substringFromIndex: 8];
}


@dynamic name, nick;


- (NSString*) username {
    return [self.class usernameFromDocID: self.document.documentID];
}


- (NSString*) email {
    NSString* email = [self getValueOfProperty: @"email"];
    if (!email) {
        // If no explicit email, assume the username is a valid email if it contains an "@":
        NSString* username = self.username;
        if ([username rangeOfString: @"@"].length > 0)
            email = username;
    }
    return email;
}


- (NSString*) displayName {
    return self.name ?: (self.nick ?: self.username);
}


- (bool) isMe {
    return [self.username isEqualToString: [[ChatStore sharedInstance] username]];
}


- (void) didLoadFromDocument {
    // Invalidate cached picture:
    _picture = nil;
    _checkedPicture = false;
    [super didLoadFromDocument];
}


- (UIImage*) picture {
    UIImage* picture = _picture;    // _picture is weak, so assign to local var first
    if (!_checkedPicture && _picture == nil) {
        NSData* pictureData = [[self attachmentNamed: @"avatar"] body];
        if (pictureData)
            picture = [[UIImage alloc] initWithData: pictureData];
        _picture = picture;
        _checkedPicture = true;
    }
    return picture;
}


+ (UserProfile*) createInDatabase: (CBLDatabase*)database
                     withUsername: (NSString*)username
{
    NSString* docID = [self docIDForUsername: username];
    CBLDocument* doc = [database documentWithID: docID];
    UserProfile* profile = [UserProfile modelForDocument: doc];

    [profile setValue: @"profile" ofProperty: @"type"];

    NSString* nick = username;
    NSRange at = [username rangeOfString: @"@"];
    if (at.length > 0) {
        nick = [username substringToIndex: at.location];
        [profile setValue: username ofProperty: @"email"];
    }
    [profile setValue: nick ofProperty: @"nick"];

    NSError* error;
    if (![profile save: &error])
        return nil;
    return profile;
}


- (void) setName: (NSString*)name nick: (NSString*)nick {
    self.autosaves = true;
    [self setValue: name ofProperty: @"name"];
    [self setValue: nick ofProperty: @"nick"];
}

- (void) setPicture:(UIImage *)picture {
    self.autosaves = true;
    CBLAttachment* att = nil;
    if (picture) {
        NSData* imageData = UIImageJPEGRepresentation(picture, 0.6);
        att = [[CBLAttachment alloc] initWithContentType: @"image/jpeg"
                                                    body: imageData];
    }
    [self addAttachment: att named: @"avatar"];
}


+ (UIImage*) loadGravatarForEmail: (NSString*)email {
    static NSMutableDictionary* sGravatars;
    
    if (!email || [email rangeOfString: @"@"].length == 0)
        return nil;     // not an email address
    email = email.lowercaseString;
    
    UIImage* picture = sGravatars[email];
    if (!picture) {
        NSData* data = [email dataUsingEncoding: NSUTF8StringEncoding];
        uint8_t md5[16];
        CC_MD5(data.bytes, data.length, md5);
        NSString *md5email = [NSString stringWithFormat:
                          @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          md5[0], md5[1], md5[2],  md5[3],  md5[4],  md5[5],  md5[6],  md5[7],
                          md5[8], md5[9], md5[10], md5[11], md5[12], md5[13], md5[14], md5[15] ];
        NSString* urlStr = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%@?d=retro]",
                            md5email];
        NSURL* url = [NSURL URLWithString: urlStr];
        
        NSData* pictureData = [NSData dataWithContentsOfURL: url];
        NSLog(@"Gravatar for %@ <%@> -- %d bytes", email, urlStr, pictureData.length);
        if (!pictureData)
            return nil;
        picture = [[UIImage alloc] initWithData: pictureData];
        if (!picture)
            return nil;
        
        if (!sGravatars)
            sGravatars = [NSMutableDictionary dictionary];
        sGravatars[email] = picture;
    }
    return picture;
}


+ (NSString*) listOfNames: (id)userArrayOrSet {
    NSMutableString* names = [NSMutableString string];
    for (UserProfile* profile in userArrayOrSet) {
        if (!profile.isMe) {
            if (names.length > 0)
                [names appendString: @", "];
            [names appendString: profile.displayName];
        }
    }
    return names;
}


@end
