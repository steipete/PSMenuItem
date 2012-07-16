PSMenuItem
=============

A block based UIMenuItem subclass.

The inflexible @selector based approach in UIMenuItem was driving me crazy.
I searched quite a while for a block-based UIMenuItem, but couldn't find one.
So finally, I sat down and wrote my own implementation for [my iOS PDF framework PSKit](http://pspdfkit.com).

If you are as annoyed about the missing target/action pattern, as I am, you will *love* this. [Also read the in-depth article on my website.](http://petersteinberger.com/blog/2012/hacking-block-support-into-uimenuitem/)

## How to use
``` objective-c
    PSMenuItem *actionItem = [[PSMenuItem alloc] initWithTitle:@"Action 1" block:^{
        [[[UIAlertView alloc] initWithTitle:@"Message" message:@"From a block!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];

    PSMenuItem *submenuItem = [[PSMenuItem alloc] initWithTitle:@"Submenu..." block:^{
        [UIMenuController sharedMenuController].menuItems = @[
        [[PSMenuItem alloc] initWithTitle:@"Back..." block:^{
            [self buttonPressed:button];
        }],
        [[PSMenuItem alloc] initWithTitle:@"Sub 1" block:^{
            NSLog(@"Sub 1 pressed");
        }]];
        [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
    }];

    [UIMenuController sharedMenuController].menuItems = @[actionItem, submenuItem];
    [[UIMenuController sharedMenuController] setTargetRect:button.bounds inView:button];
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
```

PSMenuItem uses ARC and is tested with Xcode 4.4 and 4.5DP3 (iOS 4.3+)

The code looks a bit scary and involves swizzling certain methods, but it's actually not that bad. No private API is used, and it's highly unlikely that Apple ever changes something as basic as the UIResponder chain.

## Creator

[Peter Steinberger](http://github.com/steipete)
[@steipete](https://twitter.com/steipete)

I'd love a thank you tweet if you find this useful.

## License

PSMenuItem is available under the MIT license. See the LICENSE file for more info.