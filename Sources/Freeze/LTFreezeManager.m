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
        manager = [[LTFreezeManager alloc] init];
    });

    return manager;
}

- (UIWindow *)currentKeyWindow
{
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;

        if (windowScene.activationState != UISceneActivationStateForegroundActive) {
            continue;
        }

        for (UIWindow *window in windowScene.windows) {

            if (window.isKeyWindow) {
                return window;
            }
        }
    }

    return nil;
}

- (UIImage *)snapshotOfWindow:(UIWindow *)window
{
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

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {

        [window drawViewHierarchyInRect:window.bounds
                     afterScreenUpdates:NO];
    }];
}

- (void)freezeCurrentScreen
{
    if (self.frozen) {
        return;
    }

    UIWindow *sourceWindow = [self currentKeyWindow];

    if (!sourceWindow) {
        return;
    }

    UIImage *snapshot = [self snapshotOfWindow:sourceWindow];

    if (!snapshot) {
        return;
    }

    UIWindowScene *windowScene =
        (UIWindowScene *)sourceWindow.windowScene;

    if (!windowScene) {
        return;
    }

    UIWindow *freezeWindow =
        [[UIWindow alloc] initWithWindowScene:windowScene];

    freezeWindow.frame = windowScene.coordinateSpace.bounds;
    freezeWindow.windowLevel = UIWindowLevelStatusBar + 1;
    freezeWindow.backgroundColor = UIColor.blackColor;

    UIImageView *imageView =
        [[UIImageView alloc] initWithFrame:freezeWindow.bounds];

    imageView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    imageView.image = snapshot;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.userInteractionEnabled = YES;

    UITapGestureRecognizer *doubleTap =
        [[UITapGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(unfreeze)];

    doubleTap.numberOfTapsRequired = 2;

    [imageView addGestureRecognizer:doubleTap];

    [freezeWindow addSubview:imageView];

    self.freezeWindow = freezeWindow;
    self.freezeImageView = imageView;

    freezeWindow.hidden = NO;

    self.frozen = YES;

    NSLog(@"[LinguaTweak] 冻结已开启");
}

- (void)unfreeze
{
    if (!self.frozen) {
        return;
    }

    [UIView animateWithDuration:0.2
                     animations:^{
        self.freezeWindow.alpha = 0.0;
    }
                     completion:^(BOOL finished) {

        self.freezeWindow.hidden = YES;
        self.freezeWindow = nil;
        self.freezeImageView = nil;
    }];

    self.frozen = NO;

    NSLog(@"[LinguaTweak] 冻结已解除");
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
