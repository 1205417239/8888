#import <UIKit/UIKit.h>

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    %orig;

    NSLog(@"[LinguaTweak] Template loaded successfully.");
}

%end

%ctor
{
    @autoreleasepool {
        NSLog(@"[LinguaTweak] Template initialized.");
    }
}
