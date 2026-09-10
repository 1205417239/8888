#import <UIKit/UIKit.h>

static UIView *LTFreezeOverlay = nil;
static BOOL LTFreezeEnabled = NO;
static BOOL LTVolumeUpPressed = NO;
static NSTimeInterval LTVolumeUpTime = 0;

static void LTToggleFreeze(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{

        UIWindow *window = [UIApplication sharedApplication].keyWindow;

        if (!window) {
            return;
        }

        if (!LTFreezeEnabled) {

            LTFreezeOverlay =
                [[UIView alloc] initWithFrame:window.bounds];

            LTFreezeOverlay.autoresizingMask =
                UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;

            LTFreezeOverlay.backgroundColor =
                [UIColor colorWithWhite:0.0 alpha:0.05];

            LTFreezeOverlay.userInteractionEnabled = YES;
            LTFreezeOverlay.exclusiveTouch = YES;

            [window addSubview:LTFreezeOverlay];

            LTFreezeEnabled = YES;

            NSLog(@"[LinguaTweak] 冻结已开启");

        } else {

            [LTFreezeOverlay removeFromSuperview];

            LTFreezeOverlay = nil;

            LTFreezeEnabled = NO;

            NSLog(@"[LinguaTweak] 冻结已解除");
        }
    });
}

%hook SpringBoard

- (BOOL)_handlePhysicalButtonEvent:(UIPressesEvent *)event
{
    BOOL result = %orig;

    if (!event) {
        return result;
    }

    NSTimeInterval now =
        [[NSDate date] timeIntervalSince1970];

    for (UIPress *press in event.allPresses) {

        if (press.force != 1) {
            continue;
        }

        NSInteger type = press.type;

        /*
         * 102：音量＋
         * 104：侧边键
         */

        if (type == 102) {

            LTVolumeUpPressed = YES;
            LTVolumeUpTime = now;

            continue;
        }

        if (type == 104) {

            if (LTVolumeUpPressed &&
                (now - LTVolumeUpTime) <= 0.8) {

                LTVolumeUpPressed = NO;
                LTVolumeUpTime = 0;

                LTToggleFreeze();
            }

            continue;
        }
    }

    if (LTVolumeUpPressed &&
        (now - LTVolumeUpTime) > 0.8) {

        LTVolumeUpPressed = NO;
        LTVolumeUpTime = 0;
    }

    return result;
}

%end

%ctor
{
    @autoreleasepool {

        NSLog(@"[LinguaTweak] 冻结功能已加载");
    }
}
