#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface LTFreezeManager : NSObject

+ (instancetype)sharedManager;

- (void)toggleFreeze;
- (void)unfreeze;
- (BOOL)isFrozen;

@end


@interface LTSettings : NSObject

+ (instancetype)sharedSettings;

- (BOOL)isEnabled;
- (BOOL)isFreezeEnabled;
- (BOOL)isScreenshotEnabled;

@end


@interface SBScreenshotManager : NSObject
- (void)saveScreenshotsWithCompletion:(id)completion;
@end


@interface SBScreenShotter : NSObject
- (void)saveScreenshot:(BOOL)withFlash;
@end


static BOOL ltVolumeUpDown = NO;
static BOOL ltSideDown = NO;

static BOOL ltFreezeTriggered = NO;

static BOOL ltSuppressScreenshot = NO;
static CFTimeInterval ltSuppressScreenshotUntil = 0;


static void LTResetButtonState(void)
{
    ltVolumeUpDown = NO;
    ltSideDown = NO;
}


static void LTArmScreenshotSuppression(void)
{
    ltSuppressScreenshot = YES;
    ltSuppressScreenshotUntil =
        CACurrentMediaTime() + 1.5;
}


static BOOL LTShouldSuppressScreenshot(void)
{
    if (!ltSuppressScreenshot) {
        return NO;
    }

    if (CACurrentMediaTime() <= ltSuppressScreenshotUntil) {
        return YES;
    }

    ltSuppressScreenshot = NO;

    return NO;
}


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


static BOOL LTPressIsDown(id press)
{
    if (!press) {
        return NO;
    }

    if (![press respondsToSelector:@selector(phase)]) {
        return NO;
    }

    NSInteger phase = 0;

    @try {
        phase = (NSInteger)[press phase];
    }
    @catch (NSException *exception) {
        return NO;
    }

    /*
     * UIPressPhaseBegan = 1
     * UIPressPhaseChanged = 2
     * UIPressPhaseStationary = 3
     *
     * 只要不是结束/取消，就认为按键仍然处于按下状态。
     */
    return phase == 1 ||
           phase == 2 ||
           phase == 3;
}


static BOOL LTPressIsReleased(id press)
{
    if (!press) {
        return NO;
    }

    if (![press respondsToSelector:@selector(phase)]) {
        return NO;
    }

    NSInteger phase = 0;

    @try {
        phase = (NSInteger)[press phase];
    }
    @catch (NSException *exception) {
        return NO;
    }

    /*
     * UIPressPhaseEnded = 4
     * UIPressPhaseCancelled = 5
     */
    return phase == 4 ||
           phase == 5;
}


static NSInteger LTPressType(id press)
{
    if (!press) {
        return 0;
    }

    if (![press respondsToSelector:@selector(type)]) {
        return 0;
    }

    @try {
        return (NSInteger)[press type];
    }
    @catch (NSException *exception) {
        return 0;
    }
}


static void LTProcessPressesEvent(id event)
{
    if (!event) {
        return;
    }

    if (![event respondsToSelector:@selector(allPresses)]) {
        NSLog(@"[LinguaTweak] 未识别到 UIPressesEvent");

        return;
    }

    NSSet *presses = nil;

    @try {
        presses = [event allPresses];
    }
    @catch (NSException *exception) {
        NSLog(@"[LinguaTweak] 获取实体按键集合失败: %@", exception);

        return;
    }

    if (![presses isKindOfClass:[NSSet class]]) {
        return;
    }

    BOOL volumePressed = NO;
    BOOL sidePressed = NO;

    BOOL volumeReleased = NO;
    BOOL sideReleased = NO;

    for (id press in presses) {

        NSInteger type =
            LTPressType(press);

        BOOL down =
            LTPressIsDown(press);

        BOOL released =
            LTPressIsReleased(press);

        /*
         * 102 = 音量+
         */
        if (type == 102) {

            if (down) {
                volumePressed = YES;
            }

            if (released) {
                volumeReleased = YES;
            }
        }

        /*
         * 104 = 侧边键
         */
        else if (type == 104) {

            if (down) {
                sidePressed = YES;
            }

            if (released) {
                sideReleased = YES;
            }
        }
    }

    if (volumePressed) {
        ltVolumeUpDown = YES;
    }

    if (sidePressed) {
        ltSideDown = YES;
    }

    /*
     * 真正的组合键触发点。
     *
     * 两个键都处于按下状态时，
     * 立即消费截图并执行冻结。
     */
    if (ltVolumeUpDown && ltSideDown && !ltFreezeTriggered) {

        ltFreezeTriggered = YES;

        LTSettings *settings =
            [LTSettings sharedSettings];

        if ([settings isEnabled] &&
            [settings isFreezeEnabled]) {

            if ([settings isScreenshotEnabled]) {
                LTArmScreenshotSuppression();
            }

            NSLog(@"[LinguaTweak] 检测到音量+与侧边键组合");

            dispatch_async(dispatch_get_main_queue(), ^{
                LTTriggerFreeze();
            });
        }
    }

    /*
     * 任意一个组合键释放后，
     * 清除本次组合状态。
     */
    if (volumeReleased ||
        sideReleased) {

        ltVolumeUpDown = NO;
        ltSideDown = NO;
        ltFreezeTriggered = NO;
    }
}


%hook SpringBoard

- (void)_handlePhysicalButtonEvent:(id)event
{
    LTSettings *settings =
        [LTSettings sharedSettings];

    if (![settings isEnabled] ||
        ![settings isFreezeEnabled]) {

        %orig(event);

        return;
    }

    /*
     * 这是本版本最重要的改变：
     *
     * 不再直接对 event 调用 type / force。
     * 按照 UIPressesEvent 的结构读取 allPresses。
     */
    LTProcessPressesEvent(event);

    /*
     * 如果两个键都已经同时按下，
     * 不再把这次实体按键事件继续交给 SpringBoard。
     *
     * 这样可以阻断系统继续形成原生截图组合。
     */
    if (ltVolumeUpDown &&
        ltSideDown) {

        NSLog(@"[LinguaTweak] 已消费冻结组合键");

        return;
    }

    /*
     * 如果冻结组合已经触发，
     * 接下来的释放事件也不继续交给 SpringBoard。
     */
    if (ltFreezeTriggered) {

        return;
    }

    %orig(event);
}

%end


/*
 * 第一截图入口：
 *
 * 新版/部分系统截图流程会进入
 * SBScreenshotManager。
 */
%hook SBScreenshotManager

- (void)saveScreenshotsWithCompletion:(id)completion
{
    LTSettings *settings =
        [LTSettings sharedSettings];

    if ([settings isEnabled] &&
        [settings isFreezeEnabled] &&
        [settings isScreenshotEnabled] &&
        LTShouldSuppressScreenshot()) {

        NSLog(@"[LinguaTweak] 已拦截 SBScreenshotManager 原生截图");

        return;
    }

    %orig(completion);
}

%end


/*
 * 第二截图入口：
 *
 * 某些系统流程仍然会经过 SBScreenShotter。
 */
%hook SBScreenShotter

- (void)saveScreenshot:(BOOL)withFlash
{
    LTSettings *settings =
        [LTSettings sharedSettings];

    if ([settings isEnabled] &&
        [settings isFreezeEnabled] &&
        [settings isScreenshotEnabled] &&
        LTShouldSuppressScreenshot()) {

        NSLog(@"[LinguaTweak] 已拦截 SBScreenShotter 原生截图");

        return;
    }

    %orig(withFlash);
}

%end


%ctor
{
    @autoreleasepool {

        NSLog(@"[LinguaTweak] Core 实体按键与截图拦截模块已加载");
    }
}
