#import <UIKit/UIKit.h>

@interface SpringBoard : NSObject

- (BOOL)_handlePhysicalButtonEvent:(UIPressesEvent *)event;

@end

static UIView *LTFreezeOverlay = nil;
static BOOL LTFreezeEnabled = NO;

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

    /*
     * ScreenFreeze 使用 SpringBoard 的实体按键事件
     * 作为冻结控制入口。
     *
     * 这里检测一次实体按键事件，
     * 不改变系统原本的按键处理结果。
     */

    if (event && event.allPresses.count > 0) {

        BOOL hasVolumeUp = NO;
        BOOL hasSideButton = NO;

        for (UIPress *press in event.allPresses) {

            /*
             * 私有实体按键类型：
             *
             * 105：
             * 侧边/锁定相关按键
             *
             * 其他实体按键：
             * 用于配合检测组合键
             */

            if (press.type == 105) {
                hasSideButton = YES;
            } else if (press.force > 0) {
                hasVolumeUp = YES;
            }
        }

        if (hasVolumeUp && hasSideButton) {
            LTToggleFreeze();
        }
    }

    return result;
}

%end

%ctor
{
    @autoreleasepool {

        NSLog(@"[LinguaTweak] 冻结按键功能已加载");
    }
}
