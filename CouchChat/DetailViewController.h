//
//  DetailViewController.h
//  CouchChat
//
//  Created by Jens Alfke on 2/13/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
