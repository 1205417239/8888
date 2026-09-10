#import <UIKit/UIKit.h>

@interface LTFreezeManager : NSObject

+ (instancetype)sharedManager;

- (void)toggleFreeze;

@end

%hook UIWindow

- (void)touchesEnded:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event
{
    %orig;

    UITouch *touch = [touches anyObject];

    if (!touch) {
        return;
    }

    if (touch.tapCount == 2) {
        NSLog(@"[LinguaTweak] 双击触发 Freeze");

        [[LTFreezeManager sharedManager] toggleFreeze];
    }
}

%end

%ctor
{
    @autoreleasepool {
        NSLog(@"[LinguaTweak] Freeze trigger loaded.");
    }
}
