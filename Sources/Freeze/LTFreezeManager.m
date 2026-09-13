#import <UIKit/UIKit.h>

@interface LTFreezeManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, assign, readonly, getter=isFrozen) BOOL frozen;

- (void)freezeCurrentScreen;
- (void)unfreeze;
- (void)toggleFreeze;

@end


@interface LTFreezeManager ()

@property (nonatomic, strong) UIWindow *freezeWindow;
@property (nonatomic, strong) UIImageView *freezeImageView;
@property (nonatomic, assign) BOOL frozen;

@end


@implementation LTFreezeManager


+ (instancetype)sharedManager
{
    static LTFreezeManager *manager;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });

    return manager;
}


- (UIWindow *)currentWindow
{
    UIApplication *application =
        UIApplication.sharedApplication;

    for (UIScene *scene in application.connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {

            continue;
        }

        UIWindow *bestWindow = nil;

        for (UIWindow *window in windowScene.windows) {

            if (window.hidden ||
                window.alpha <= 0.01 ||
                window.bounds.size.width <= 0 ||
                window.bounds.size.height <= 0) {

                continue;
            }

            if ([window isKindOfClass:NSClassFromString(@"UITextEffectsWindow")]) {
                continue;
            }

            if ([window isKindOfClass:NSClassFromString(@"UIRemoteKeyboardWindow")]) {
                continue;
            }

            if (window.windowLevel <= UIWindowLevelNormal) {
                bestWindow = window;
            }

            if (window.isKeyWindow) {
                bestWindow = window;
                break;
            }
        }

        if (bestWindow) {
            return bestWindow;
        }
    }

    return nil;
}


- (UIImage *)captureScreen
{
    /*
     * 优先使用系统屏幕截图接口。
     *
     * 这是冻结画面的来源，
     * 与原生截图保存流程不是同一件事。
     */
    UIImage *image = nil;

    Class uiClass = NSClassFromString(@"UIScreen");

    if (uiClass &&
        [uiClass respondsToSelector:
            NSSelectorFromString(@"_createSnapshot")]) {

        @try {

            image =
                [uiClass performSelector:
                    NSSelectorFromString(@"_createSnapshot")];

        }
        @catch (NSException *exception) {

            image = nil;
        }
    }

    /*
     * 如果私有接口不可用，
     * 回退到当前窗口绘制。
     */
    if (!image) {

        UIWindow *window =
            [self currentWindow];

        if (!window) {
            return nil;
        }

        UIGraphicsImageRendererFormat *format =
            [UIGraphicsImageRendererFormat preferredFormat];

        format.opaque = YES;

        UIGraphicsImageRenderer *renderer =
            [[UIGraphicsImageRenderer alloc]
                initWithBounds:window.bounds
                format:format];

        image =
            [renderer imageWithActions:
                ^(UIGraphicsImageRendererContext *context) {

            [window drawViewHierarchyInRect:
                        window.bounds
                        afterScreenUpdates:NO];
        }];
    }

    return image;
}


- (void)freezeCurrentScreen
{
    if (self.frozen) {
        return;
    }

    UIWindow *sourceWindow =
        [self currentWindow];

    if (!sourceWindow) {

        NSLog(@"[LinguaTweak] 未找到当前窗口");

        return;
    }

    UIImage *snapshot =
        [self captureScreen];

    if (!snapshot) {

        NSLog(@"[LinguaTweak] 当前画面获取失败");

        return;
    }

    UIWindowScene *windowScene =
        sourceWindow.windowScene;

    if (!windowScene) {

        NSLog(@"[LinguaTweak] 未找到当前窗口场景");

        return;
    }

    UIWindow *freezeWindow =
        [[UIWindow alloc]
            initWithWindowScene:windowScene];

    freezeWindow.frame =
        windowScene.coordinateSpace.bounds;

    /*
     * 必须高于普通 SpringBoard 窗口。
     */
    freezeWindow.windowLevel = 10000.0;

    freezeWindow.backgroundColor =
        UIColor.blackColor;

    freezeWindow.opaque = YES;

    UIImageView *imageView =
        [[UIImageView alloc]
            initWithFrame:freezeWindow.bounds];

    imageView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    imageView.image =
        snapshot;

    imageView.contentMode =
        UIViewContentModeScaleAspectFill;

    imageView.userInteractionEnabled = YES;


    /*
     * 双击解除冻结。
     */
    UITapGestureRecognizer *doubleTap =
        [[UITapGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(unfreeze)];

    doubleTap.numberOfTapsRequired = 2;

    [imageView addGestureRecognizer:doubleTap];

    [freezeWindow addSubview:imageView];

    self.freezeWindow =
        freezeWindow;

    self.freezeImageView =
        imageView;

    self.frozen = YES;

    freezeWindow.hidden = NO;

    [freezeWindow makeKeyAndVisible];

    NSLog(@"[LinguaTweak] 冻结画面已显示");
}


- (void)unfreeze
{
    if (!self.frozen) {
        return;
    }

    UIWindow *window =
        self.freezeWindow;

    self.frozen = NO;

    self.freezeImageView = nil;
    self.freezeWindow = nil;

    [UIView animateWithDuration:0.15
                     animations:^{
        window.alpha = 0.0;
    }
                     completion:^(BOOL finished) {

        window.hidden = YES;
    }];

    NSLog(@"[LinguaTweak] 冻结画面已解除");
}


- (void)toggleFreeze
{
    if (self.frozen) {

        [self unfreeze];

    } else {

        [self freezeCurrentScreen];
    }
}


@end
