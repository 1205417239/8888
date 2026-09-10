#import <UIKit/UIKit.h>

static UIWindow *LTFreezeWindow = nil;
static UIView *LTFreezeOverlay = nil;
static BOOL LTFreezeEnabled = NO;

static BOOL LTVolumeUpPending = NO;
static NSTimeInterval LTVolumeUpTime = 0;

static void LTSetFrozen(BOOL frozen)
{
    dispatch_async(dispatch_get_main_queue(), ^{

        UIWindow *window =
            [UIApplication sharedApplication].keyWindow;

        if (!window) {
            return;
        }

        if (frozen) {

            if (LTFreezeEnabled) {
                return;
            }

            LTFreezeWindow =
                [[UIWindow alloc] initWithFrame:window.bounds];

            LTFreezeWindow.windowLevel =
                UIWindowLevelAlert + 100;

            LTFreezeWindow.backgroundColor =
                [UIColor clearColor];

            LTFreezeWindow.hidden = NO;

            LTFreezeOverlay =
                [[UIView alloc] initWithFrame:LTFreezeWindow.bounds];

            LTFreezeOverlay.autoresizingMask =
                UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;

            LTFreezeOverlay.backgroundColor =
                [UIColor colorWithWhite:0.0 alpha:0.20];

            LTFreezeOverlay.userInteractionEnabled = YES;
            LTFreezeOverlay.exclusiveTouch = YES;

            [LTFreezeWindow addSubview:LTFreezeOverlay];

            LTFreezeEnabled = YES;

            NSLog(@"[LinguaTweak] 冻结已开启");

        } else {

            [LTFreezeOverlay removeFromSuperview];

            LTFreezeOverlay = nil;

            LTFreezeWindow.hidden = YES;
            LTFreezeWindow = nil;

            LTFreezeEnabled = NO;

            NSLog(@"[LinguaTweak] 冻结已解除");
        }
    });
}

static void LTToggleFreeze(void)
{
    LTSetFrozen(!LTFreezeEnabled);
}

static BOOL LTIsVolumeUp(UIPress *press)
{
    return press.type == 102;
}

static BOOL LTIsSideButton(UIPress *press)
{
    return press.type == 104;
}

%hook SpringBoard

- (BOOL)_handlePhysicalButtonEvent:(UIPressesEvent *)event
{
    if (!event) {
        return %orig;
    }

    NSTimeInterval now =
        [[NSDate date] timeIntervalSince1970];

    BOOL volumeUpDown = NO;
    BOOL sideButtonDown = NO;

    for (UIPress *press in event.allPresses) {

        if (press.force != 1) {
            continue;
        }

        if (LTIsVolumeUp(press)) {
            volumeUpDown = YES;
        }

        if (LTIsSideButton(press)) {
            sideButtonDown = YES;
        }
    }

    if (volumeUpDown) {

        LTVolumeUpPending = YES;
        LTVolumeUpTime = now;

        /*
         * 这里暂时放行音量＋。
         * 真正阻止系统截图的关键是：
         * 在后续侧边键事件到来时拦截它。
         */

        if (!LTFreezeEnabled) {
            return %orig;
        }

        return YES;
    }

    if (sideButtonDown) {

        BOOL isVolumeSideCombo =
            LTVolumeUpPending &&
            ((now - LTVolumeUpTime) <= 0.8);

        LTVolumeUpPending = NO;
        LTVolumeUpTime = 0;

        if (isVolumeSideCombo) {

            LTToggleFreeze();

            /*
             * 不调用 %orig。
             *
             * 这样这一次侧边键不会继续交给
             * SpringBoard 的系统截图流程。
             */
            return YES;
        }

        if (LTFreezeEnabled) {

            /*
             * 冻结状态下阻止侧边键继续触发
             * SpringBoard 的普通操作。
             */
            return YES;
        }

        return %orig;
    }

    if (LTVolumeUpPending &&
        ((now - LTVolumeUpTime) > 0.8)) {

        LTVolumeUpPending = NO;
        LTVolumeUpTime = 0;
    }

    if (LTFreezeEnabled) {
        return YES;
    }

    return %orig;
}

- (void)_simulateHomeButtonPress
{
    if (LTFreezeEnabled) {
        return;
    }

    %orig;
}

%end

%hook SBSystemGestureManager

- (BOOL)isGestureWithTypeAllowed:(unsigned long long)type
{
    if (LTFreezeEnabled) {
        return NO;
    }

    return %orig;
}

%end

%hook SBLockHardwareButtonActions

- (void)performLongPressActions
{
    if (LTFreezeEnabled) {
        return;
    }

    %orig;
}

%end

%ctor
{
    @autoreleasepool {

        NSLog(@"[LinguaTweak] 冻结功能已加载");
    }
}
