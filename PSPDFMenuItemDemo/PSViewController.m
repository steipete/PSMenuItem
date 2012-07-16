//
//  PSViewController.m
//  PSMenuItemDemo
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  This is code from http://pspdfkit.com.
//

#import "PSViewController.h"
#import "PSMenuItem.h"

@implementation PSViewController

// add support for PSMenuItem. Needs to be called once per class.
+ (void)load {
    [PSMenuItem installMenuHandlerForObject:self];
}

+ (void)initialize {
    [PSMenuItem installMenuHandlerForObject:self];
}

- (IBAction)buttonPressed:(UIButton *)button {
    PSMenuItem *actionItem = [[PSMenuItem alloc] initWithTitle:@"Action 1" block:^{
        [[[UIAlertView alloc] initWithTitle:@"Action 1" message:@"From a block!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];
    
    PSMenuItem *action2Item = [[PSMenuItem alloc] initWithTitle:@"Action 2" block:^{
        [[[UIAlertView alloc] initWithTitle:@"Action 2" message:@"From a block!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];

    PSMenuItem *submenuItem = [[PSMenuItem alloc] initWithTitle:@"Submenu..." block:^{
        [UIMenuController sharedMenuController].menuItems = @[
        [[PSMenuItem alloc] initWithTitle:@"Back..." block:^{
            [self buttonPressed:button];
        }],
        [[PSMenuItem alloc] initWithTitle:@"Sub 1" block:NULL],
        [[PSMenuItem alloc] initWithTitle:@"Sub 2" block:^{
            NSLog(@"Sub 2 pressed.");
        }]];

        [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
    }];

    [UIMenuController sharedMenuController].menuItems = @[actionItem, action2Item, submenuItem];
    [[UIMenuController sharedMenuController] setTargetRect:button.bounds inView:button];
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
}

@end
