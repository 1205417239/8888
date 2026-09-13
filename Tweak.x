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
    static LTSettings *settings;
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
    NSNumber *value =
        [[self settingsDomain] objectForKey:key];

    return value ? [value boolValue] : defaultValue;
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


@interface LTPhysicalButtonEvent : NSObject
- (NSInteger)type;
- (NSInteger)force;
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


static void LTResetState(void)
{
    ltVolumeUpDown = NO;
    ltSideDown = NO;
    ltConsumeNextPhysicalEvent = NO;
    ltSuppressScreenshot = NO;
    ltSuppressScreenshotUntil = 0;
}


static void LTArmScreenshotSuppression(void)
{
    ltSuppressScreenshot = YES;
    ltSuppressScreenshotUntil =
        CACurrentMediaTime() + 1.0;
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
    LTSettings *settings =
        [LTSettings sharedSettings];

    if (![settings isEnabled] ||
        ![settings isFreezeEnabled]) {
        return;
    }

    @try {
        LTFreezeManager *manager =
            [LTFreezeManager sharedManager];

        if ([manager respondsToSelector:@selector(toggleFreeze)]) {
            [manager toggleFreeze];
            NSLog(@"[LinguaTweak] 冻结状态已切换");
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[LinguaTweak] 冻结操作异常: %@", exception);
    }
}


static void LTHandleCombination(void)
{
    LTSettings *settings =
        [LTSettings sharedSettings];

    if (![settings isEnabled] ||
        ![settings isFreezeEnabled]) {
        LTResetState();
        return;
    }

    if (!(ltVolumeUpDown && ltSideDown)) {
        return;
    }

    if ([settings isScreenshotEnabled]) {
        LTArmScreenshotSuppression();
    }

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
    LTSettings *settings =
        [LTSettings sharedSettings];

    if (![settings isEnabled] ||
        ![settings isFreezeEnabled]) {
        LTResetState();
        %orig(event);
        return;
    }

    BOOL matchedCombination = NO;

    @try {
        LTPhysicalButtonEvent *physicalEvent =
            (LTPhysicalButtonEvent *)event;

        NSInteger type = 0;
        NSInteger force = 0;

        if ([physicalEvent respondsToSelector:@selector(type)]) {
            type = [physicalEvent type];
        }

        if ([physicalEvent respondsToSelector:@selector(force)]) {
            force = [physicalEvent force];
        }

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
            return;
        }

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


%hook SBScreenShotter

- (void)saveScreenshot:(BOOL)withFlash
{
    LTSettings *settings =
        [LTSettings sharedSettings];

    if (![settings isEnabled] ||
        ![settings isScreenshotEnabled]) {
        %orig(withFlash);
        return;
    }

    if (LTShouldSuppressScreenshot()) {
        NSLog(@"[LinguaTweak] 已拦截系统截图");
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
