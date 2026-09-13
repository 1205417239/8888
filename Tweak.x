#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface LTSettings : NSObject

+ (instancetype)sharedSettings;

- (BOOL)isEnabled;
- (BOOL)isFreezeEnabled;
- (BOOL)isScreenshotEnabled;
- (BOOL)isTranslateEnabled;
- (BOOL)isToolbarEnabled;

@end

@implementation LTSettings

+ (instancetype)sharedSettings
{
    static LTSettings *settings = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        settings = [[self alloc] init];
    });

    return settings;
}

- (NSDictionary *)settingsDomain
{
    NSDictionary *domain =
        [[NSUserDefaults standardUserDefaults]
            persistentDomainForName:@"com.lingua.tweak"];

    return domain ?: @{};
}

- (BOOL)valueForKey:(NSString *)key defaultValue:(BOOL)defaultValue
{
    NSDictionary *domain = [self settingsDomain];
    id value = domain[key];

    if (value == nil) {
        return defaultValue;
    }

    return [value boolValue];
}

- (BOOL)isEnabled
{
    return [self valueForKey:@"LinguaTweakEnabled"
                defaultValue:YES];
}

- (BOOL)isFreezeEnabled
{
    return [self valueForKey:@"FreezeEnabled"
                defaultValue:YES];
}

- (BOOL)isScreenshotEnabled
{
    return [self valueForKey:@"ScreenshotEnabled"
                defaultValue:YES];
}

- (BOOL)isTranslateEnabled
{
    return [self valueForKey:@"TranslateEnabled"
                defaultValue:YES];
}

- (BOOL)isToolbarEnabled
{
    return [self valueForKey:@"ToolbarEnabled"
                defaultValue:YES];
}

@end


@interface LTFreezeManager : NSObject
+ (instancetype)sharedManager;
- (void)toggleFreeze;
- (void)unfreeze;
- (BOOL)isFrozen;
@end

@interface SBScreenShotter : NSObject
@end


static BOOL ltVolumeUpDown = NO;
static BOOL ltSideDown = NO;
static BOOL ltConsumeNextPhysicalEvent = NO;
static BOOL ltSuppressScreenshot = NO;
static CFTimeInterval ltSuppressScreenshotUntil = 0;


static void LTArmScreenshotSuppression(void)
{
    ltSuppressScreenshot = YES;
    ltSuppressScreenshotUntil = CACurrentMediaTime() + 1.0;
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


static void LTToggleFreeze(void)
{
    if (![[LTSettings sharedSettings] isEnabled]) {
        return;
    }

    if (![[LTSettings sharedSettings] isFreezeEnabled]) {
        return;
    }

    @try {
        LTFreezeManager *manager =
            [LTFreezeManager sharedManager];

        [manager toggleFreeze];

        NSLog(@"[LinguaTweak] 冻结状态已切换");
    }
    @catch (NSException *exception) {
        NSLog(@"[LinguaTweak] 冻结操作异常: %@", exception);
    }
}


static void LTHandleCombination(void)
{
    if (![[LTSettings sharedSettings] isEnabled]) {
        return;
    }

    if (![[LTSettings sharedSettings] isFreezeEnabled]) {
        return;
    }

    if (!(ltVolumeUpDown && ltSideDown)) {
        return;
    }

    /*
     * 先标记截图抑制，再切换冻结。
     * 如果系统随后进入 SBScreenShotter，
     * saveScreenshot: 会被下面的 Hook 截住。
     */
    LTArmScreenshotSuppression();

    ltConsumeNextPhysicalEvent = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        LTToggleFreeze();
    });

    ltVolumeUpDown = NO;
    ltSideDown = NO;
}


%hook SpringBoard

- (void)_handlePhysicalButtonEvent:(id)event
{
    /*
     * LinguaTweak 总开关关闭：
     * 完全交还给系统原始处理流程。
     */
    if (![[LTSettings sharedSettings] isEnabled]) {
        %orig(event);
        return;
    }

    /*
     * 冻结模块关闭：
     * 不处理冻结组合键，也不拦截任何实体按键。
     */
    if (![[LTSettings sharedSettings] isFreezeEnabled]) {
        %orig(event);
        return;
    }

    BOOL matchedCombination = NO;

    @try {
        NSInteger type = 0;
        NSInteger force = 0;

        if ([event respondsToSelector:@selector(type)]) {
            type = (NSInteger)[event type];
        }

        if ([event respondsToSelector:@selector(force)]) {
            force = (NSInteger)[event force];
        }

        /*
         * 私有实体按键事件：
         *
         * 102 = 音量+
         * 104 = 侧边键
         *
         * 只在按下时记录，释放时清除对应状态。
         */
        if (type == 102) {
            ltVolumeUpDown = (force != 0);

            if (ltVolumeUpDown && ltSideDown) {
                matchedCombination = YES;
            }
        }
        else if (type == 104) {
            ltSideDown = (force != 0);

            if (ltSideDown && ltVolumeUpDown) {
                matchedCombination = YES;
            }
        }

        if (matchedCombination) {
            LTHandleCombination();

            /*
             * 不把组合键继续交给 SpringBoard。
             * 同时 SBScreenShotter Hook 作为第二道保险。
             */
            return;
        }

        /*
         * 组合键已经触发后的释放事件不继续参与系统处理。
         */
        if (ltConsumeNextPhysicalEvent &&
            (type == 102 || type == 104)) {

            if (force == 0) {
                ltConsumeNextPhysicalEvent = NO;
            }

            return;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[LinguaTweak] 实体按键处理异常: %@", exception);
    }

    %orig(event);
}

%end


/*
 * 第二道保险：
 *
 * 如果系统截图流程最终进入 SBScreenShotter，
 * 只有我们刚刚识别出的冻结组合键窗口才阻止截图。
 */
%hook SBScreenShotter

- (void)saveScreenshot:(BOOL)withFlash
{
    /*
     * LinguaTweak 总开关关闭时，
     * 不参与系统截图流程。
     */
    if (![[LTSettings sharedSettings] isEnabled]) {
        %orig(withFlash);
        return;
    }

    if (LTShouldSuppressScreenshot()) {
        NSLog(@"[LinguaTweak] 已拦截冻结组合键产生的系统截图");
        return;
    }

    %orig(withFlash);
}

%end


%ctor
{
    @autoreleasepool {
        NSLog(@"[LinguaTweak] Core 配置中心已加载");
    }
}
