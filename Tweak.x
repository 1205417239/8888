#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "Sources/Settings/LTSettings.h"

@interface LTFreezeManager : NSObject

+ (instancetype)sharedManager;

- (void)toggleFreeze;
- (void)unfreeze;
- (BOOL)isFrozen;

@end


@interface SBScreenshotManager : NSObject
- (void)saveScreenshotsWithCompletion:(id)completion;
@end


@interface SBScreenShotter : NSObject
- (void)saveScreenshot:(BOOL)withFlash;
@end


static void LTTriggerFreeze(void)
{
    LTSettings *settings =
        [LTSettings sharedSettings];

    if (![settings isEnabled]) {
        return;
    }

    if (![settings isFreezeEnabled]) {
        return;
    }

    @try {

        LTFreezeManager *manager =
            [LTFreezeManager sharedManager];

        [manager toggleFreeze];

        NSLog(@"[LinguaTweak] 冻结功能已执行");

    }
    @catch (NSException *exception) {

        NSLog(@"[LinguaTweak] 冻结功能异常: %@", exception);
    }
}


%hook SpringBoard

- (void)_handlePhysicalButtonEvent:(id)event
{
    // 直通，不做拦截。iOS 17 上截图手势识别不在此链路，
    // 保留 hook 仅用于后续可能的其他快捷键扩展。
    %orig(event);
}

%end


%hook SBScreenshotManager

- (void)saveScreenshotsWithCompletion:(id)completion
{
    LTSettings *settings =
        [LTSettings sharedSettings];

    if ([settings isEnabled] &&
        [settings isFreezeEnabled]) {

        NSLog(@"[LinguaTweak] 截图触发，执行冻结");

        dispatch_async(dispatch_get_main_queue(), ^{
            LTTriggerFreeze();
        });
    }

    // 永远透传，不拦截系统截图。
    // iOS 17 截图保存走底层独立服务，此处拦截无效。
    %orig(completion);
}

%end


%hook SBScreenShotter

- (void)saveScreenshot:(BOOL)withFlash
{
    // 直通，不做拦截。
    %orig(withFlash);
}

%end


%ctor
{
    @autoreleasepool {

        NSLog(@"[LinguaTweak] Core 截图触发冻结模块已加载");
    }
}
