#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>


/*
 * SpringBoard 私有屏幕捕获接口。
 *
 * 与 drawViewHierarchyInRect: 不同，
 * 这个接口获取的是当前设备实际显示屏幕的图像。
 */
extern UIImage *_UICreateScreenUIImage(void);


@interface LTFreezeManager : NSObject

+ (instancetype)sharedManager;

- (void)freezeCurrentScreen;
- (void)unfreeze;
- (void)toggleFreeze;

@property (nonatomic, assign, readonly, getter=isFrozen) BOOL frozen;

@end


@interface LTFreezeManager ()

@property (nonatomic, strong) UIWindow *freezeWindow;
@property (nonatomic, strong) UIImageView *freezeImageView;
@property (nonatomic, assign) BOOL frozen;

@end


@implementation LTFreezeManager


+ (instancetype)sharedManager
{
    static LTFreezeManager *manager = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });

    return manager;
}


- (instancetype)init
{
    self = [super init];

    if (self) {
        _frozen = NO;
        _freezeWindow = nil;
        _freezeImageView = nil;
    }

    return self;
}


/*
 * 获取当前前台显示场景。
 */
- (UIWindowScene *)activeWindowScene
{
    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application) {
        return nil;
    }

    for (UIScene *scene in application.connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState ==
            UISceneActivationStateForegroundActive) {

            return windowScene;
        }
    }

    /*
     * 某些 SpringBoard 状态下，
     * ForegroundActive 可能暂时不存在。
     *
     * 再尝试寻找前台非 inactive 场景。
     */
    for (UIScene *scene in application.connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState !=
            UISceneActivationStateUnattached) {

            return windowScene;
        }
    }

    return nil;
}


/*
 * 获取实际设备当前屏幕图像。
 *
 * 必须在创建冻结窗口之前调用。
 * 否则有可能把冻结窗口自己截进去。
 */
- (UIImage *)captureCurrentScreen
{
    @try {

        UIImage *image =
            _UICreateScreenUIImage();

        if (!image) {
            NSLog(@"[LinguaTweak] 冻结失败：无法获取当前屏幕");
            return nil;
        }

        return image;
    }
    @catch (NSException *exception) {

        NSLog(@"[LinguaTweak] 获取屏幕图像异常：%@",
              exception);

        return nil;
    }
}


/*
 * 创建覆盖整个显示区域的冻结窗口。
 */
- (UIWindow *)createFreezeWindowForScene:(UIWindowScene *)windowScene
{
    if (!windowScene) {
        return nil;
    }

    CGRect frame =
        [UIScreen mainScreen].bounds;

    UIWindow *window =
        [[UIWindow alloc]
            initWithWindowScene:windowScene];

    if (!window) {
        return nil;
    }

    window.frame = frame;

    /*
     * 使用高层级。
     *
     * 公开的 SpringBoard tweak Lock-Master
     * 同样采用 10000 的窗口层级。
     */
    window.windowLevel = 10000.0;

    window.backgroundColor =
        [UIColor blackColor];

    window.opaque = YES;
    window.alpha = 1.0;

    /*
     * 冻结层必须接收触摸，
     * 防止下面的 App 继续操作。
     */
    window.userInteractionEnabled = YES;

    /*
     * 不抢系统 keyWindow。
     */
    window.hidden = YES;

    return window;
}


/*
 * 创建冻结画面。
 */
- (UIImageView *)createFreezeImageViewWithImage:(UIImage *)image
                                         frame:(CGRect)frame
{
    if (!image) {
        return nil;
    }

    UIImageView *imageView =
        [[UIImageView alloc]
            initWithFrame:frame];

    if (!imageView) {
        return nil;
    }

    imageView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    /*
     * 当前屏幕必须完整覆盖。
     */
    imageView.contentMode =
        UIViewContentModeScaleAspectFill;

    imageView.image = image;

    /*
     * 接收触摸，阻止下面的 App。
     */
    imageView.userInteractionEnabled = YES;

    /*
     * 双击冻结画面可以解除冻结。
     * 硬件组合键仍然可以再次解除。
     */
    UITapGestureRecognizer *doubleTap =
        [[UITapGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(unfreeze)];

    doubleTap.numberOfTapsRequired = 2;
    doubleTap.numberOfTouchesRequired = 1;

    [imageView addGestureRecognizer:doubleTap];

    return imageView;
}


/*
 * 开启冻结。
 */
- (void)freezeCurrentScreen
{
    if (self.frozen) {
        return;
    }

    /*
     * 第一步：
     * 先获取真实屏幕。
     */
    UIImage *snapshot =
        [self captureCurrentScreen];

    if (!snapshot) {
        NSLog(@"[LinguaTweak] 冻结失败：屏幕捕获为空");
        return;
    }

    /*
     * 第二步：
     * 获取当前显示场景。
     */
    UIWindowScene *windowScene =
        [self activeWindowScene];

    if (!windowScene) {
        NSLog(@"[LinguaTweak] 冻结失败：没有可用显示场景");
        return;
    }

    /*
     * 第三步：
     * 创建最高层冻结窗口。
     */
    UIWindow *window =
        [self createFreezeWindowForScene:windowScene];

    if (!window) {
        NSLog(@"[LinguaTweak] 冻结失败：无法创建冻结窗口");
        return;
    }

    /*
     * 第四步：
     * 创建屏幕静态图像层。
     */
    UIImageView *imageView =
        [self createFreezeImageViewWithImage:snapshot
                                       frame:window.bounds];

    if (!imageView) {
        NSLog(@"[LinguaTweak] 冻结失败：无法创建冻结画面");
        return;
    }

    [window addSubview:imageView];

    /*
     * 保存引用。
     */
    self.freezeWindow = window;
    self.freezeImageView = imageView;

    /*
     * 先完成布局。
     */
    [window setNeedsLayout];
    [window layoutIfNeeded];

    /*
     * 最后才显示冻结窗口。
     */
    window.hidden = NO;

    self.frozen = YES;

    NSLog(@"[LinguaTweak] 屏幕冻结已开启");
}


/*
 * 解除冻结。
 */
- (void)unfreeze
{
    if (!self.frozen) {
        return;
    }

    UIWindow *window =
        self.freezeWindow;

    UIImageView *imageView =
        self.freezeImageView;

    /*
     * 先修改状态，
     * 防止重复触发解除。
     */
    self.frozen = NO;

    if (!window) {

        self.freezeImageView = nil;
        self.freezeWindow = nil;

        NSLog(@"[LinguaTweak] 冻结已解除");
        return;
    }

    [UIView animateWithDuration:0.12
                     animations:^{
        window.alpha = 0.0;
    }
                     completion:^(BOOL finished) {

        window.hidden = YES;
        window.alpha = 1.0;

        [imageView removeFromSuperview];

        self.freezeImageView = nil;
        self.freezeWindow = nil;
    }];

    NSLog(@"[LinguaTweak] 冻结已解除");
}


/*
 * 冻结 / 解除冻结。
 */
- (void)toggleFreeze
{
    if (self.frozen) {
        [self unfreeze];
    }
    else {
        [self freezeCurrentScreen];
    }
}


@end
