//
//  SuperPlayerSmallView.m
//  SuperPlayer
//
//  Created by Mac on 2021/4/23.
//

#import "SuperPlayerSmallView.h"
#import "SuperPlayer.h"
#import "SuperPlayerView+Private.h"
#import "UIView+MMLayout.h"
#import "DataReport.h"
#import "UIView+Fade.h"

#define FLOAT_VIEW_WIDTH  200
#define FLOAT_VIEW_HEIGHT 112
@interface SuperPlayerSmallView ()<TXVodPlayListener>
@property (weak) UIView *origFatherView;
@property (nonatomic, assign) BOOL hiddenfastView;
@property (nonatomic ,strong) UIVisualEffectView *effectView;
@property (nonatomic ,strong) UIImageView *centerImage;
@end
@implementation SuperPlayerSmallView

+ (instancetype)sharedInstance {
    static SuperPlayerSmallView *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SuperPlayerSmallView alloc] init];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    //设置默认显示关闭按钮的延迟
    self.closeBtnAfterTime = 0;
    CGRect rect = CGRectMake(ScreenWidth-FLOAT_VIEW_WIDTH, ScreenHeight-FLOAT_VIEW_HEIGHT, FLOAT_VIEW_WIDTH, FLOAT_VIEW_HEIGHT);
    if (IsIPhoneX) {
        rect.origin.y -= 44;
    }
    self.floatViewRect = rect;
    self.hidden = YES;
    return self;
}

- (void)setCloseBtnAfterShow:(NSInteger)time {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.defaultCloseBtn.hidden = NO;
    });
}

- (void)setStatusBtntitle:(NSString *)statusBtntitle{
    _statusBtntitle = statusBtntitle;
    [self.defaultStatusBtn setTitle:statusBtntitle forState:UIControlStateNormal];
}

- (void)showWithVC:(UIViewController *)vc {
    _isShowing = YES;
    self.rootView.frame = self.floatViewRect;
    [vc.view addSubview:self.rootView];
    
    self.hidden = NO;
    
    self.origFatherView = self.superPlayer.fatherView;
    self.hiddenfastView = self.superPlayer.hiddenFastView;
    if (self.origFatherView != self.rootView) {
        self.superPlayer.fatherView = self.rootView;
    }
    self.superPlayer.hiddenFastView = YES;
    [self.superPlayer.controlView fadeOut:0.01];
    
    if (!self.hideClose) {
        [self.rootView addSubview:self.defaultCloseBtn];
        [self setCloseBtnAfterShow:self.closeBtnAfterTime];
        self.defaultCloseBtn.mm_width(20).mm_height(20).mm_top(6).mm_right(6);
    }
    
    if (!self.hideStatus) {
        //给图层添加一个有色边框
        self.rootView.layer.borderWidth = 1;
        self.rootView.layer.borderColor = [UIColor colorWithRed:255/255.0 green:90/255.0 blue:95/255.0 alpha:1].CGColor;
        
        [self.rootView addSubview:self.defaultStatusBtn];
        self.defaultStatusBtn.mm_width(61).mm_height(24).mm_left(0).mm_bottom(0);
        
        UIBezierPath *maskPath= [UIBezierPath bezierPathWithRoundedRect:self.defaultStatusBtn.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight | UIRectCornerBottomRight cornerRadii:CGSizeMake(12, 8)];
        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        maskLayer.frame = self.defaultStatusBtn.bounds;
        maskLayer.path = maskPath.CGPath;
        self.defaultStatusBtn.layer.mask = maskLayer;
    }
    
    if (self.customView) {
        [self.rootView bringSubviewToFront:self.customView];
    }
   
    [DataReport report:@"floatmode" param:nil];
    
    [self.superPlayer.coverImageView addSubview:self.effectView];
    [self.effectView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(UIEdgeInsetsZero);
    }];

    [self.superPlayer.coverImageView addSubview:self.centerImage];
    [self.centerImage mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(UIEdgeInsetsZero);
    }];
    self.baseVC = vc;
}

- (void)hide{
    if (!self.superPlayer) {
        return;
    }
    self.floatViewRect = self.rootView.frame;
    
    [self.rootView removeFromSuperview];
    self.hidden = YES;
    
    self.superPlayer.hiddenFastView = self.hiddenfastView;
    self.superPlayer.fatherView = self.origFatherView;
    self.superPlayer = nil;
    self.baseVC = nil;
    _isShowing = NO;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (CGRectContainsPoint(self.rootView.bounds,
                            [self.rootView convertPoint:point fromView:self])) {
        return [super pointInside:point withEvent:event];
    }
    return NO;
}

- (void)closeBtnClick:(id)sender
{
    if (self.closeHandler) {
        self.closeHandler();
    } else {
        [self hide];
        [_superPlayer resetPlayer];
        self.backController = nil;
    }
}

- (void)backBtnClick:(id)sender
{
    if (self.backHandler) {
        self.backHandler();
    } else {
        [self hide];
        [self.topNavigationController pushViewController:self.backController animated:YES];
        self.backController = nil;
    }
}

- (UINavigationController *)topNavigationController {
    UIWindow *window = [[UIApplication sharedApplication].delegate window];
    UIViewController *topViewController = [window rootViewController];
    while (true) {
        if (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        } else if ([topViewController isKindOfClass:[UINavigationController class]] && [(UINavigationController*)topViewController topViewController]) {
            topViewController = [(UINavigationController *)topViewController topViewController];
        } else if ([topViewController isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tab = (UITabBarController *)topViewController;
            topViewController = tab.selectedViewController;
        } else {
            break;
        }
    }
    return topViewController.navigationController;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self backBtnClick:nil];
}
#pragma mark - GestureRecognizer

// 手势处理
- (void)panGestureRecognizer:(UIPanGestureRecognizer *)panGesture {
    if (UIGestureRecognizerStateBegan == panGesture.state) {
    }
    else if (UIGestureRecognizerStateChanged == panGesture.state) {
        CGPoint translation = [panGesture translationInView:self];
        
        CGPoint center = self.rootView.center;
        center.x += translation.x;
        center.y += translation.y;
        self.rootView.center = center;
        
        UIEdgeInsets effectiveEdgeInsets = UIEdgeInsetsZero; // 边距可以自己调
        
        CGFloat   leftMinX = 0.0f + effectiveEdgeInsets.left;
        CGFloat    topMinY = 0.0f + effectiveEdgeInsets.top;
        CGFloat  rightMaxX = ScreenWidth - self.rootView.bounds.size.width + effectiveEdgeInsets.right;
        CGFloat bottomMaxY = ScreenHeight - self.rootView.bounds.size.height + effectiveEdgeInsets.bottom;
        
        CGRect frame = self.rootView.frame;
        frame.origin.x = frame.origin.x > rightMaxX ? rightMaxX : frame.origin.x;
        frame.origin.x = frame.origin.x < leftMinX ? leftMinX : frame.origin.x;
        frame.origin.y = frame.origin.y > bottomMaxY ? bottomMaxY : frame.origin.y;
        frame.origin.y = frame.origin.y < topMinY ? topMinY : frame.origin.y;
        self.rootView.frame = frame;
        
        // zero
        [panGesture setTranslation:CGPointZero inView:self.baseVC.view];
    }
    else if (UIGestureRecognizerStateEnded == panGesture.state) {

    }
}

/**
 * 点播事件通知
 *
 * @param player 点播对象
 * @param EvtID 参见TXLiveSDKTypeDef.h
 * @param param 参见TXLiveSDKTypeDef.h
 */
-(void) onPlayEvent:(TXVodPlayer *)player event:(int)EvtID withParam:(NSDictionary*)param
{
    
}

/**
 * 网络状态通知
 *
 * @param player 点播对象
 * @param param 参见TXLiveSDKTypeDef.h
 */
-(void) onNetStatus:(TXVodPlayer *)player withParam:(NSDictionary*)param
{
    
}

#pragma mark -getter

- (UIView *)rootView {
    if (!_rootView) {
        _rootView = [[UIView alloc] initWithFrame:CGRectZero];
        _rootView.backgroundColor = [UIColor blackColor];
        _rootView.layer.cornerRadius = 8;
        _rootView.layer.masksToBounds = YES;

        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizer:)];
        [_rootView addGestureRecognizer:panGesture];
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backBtnClick:)];
        [_rootView addGestureRecognizer:tapGesture];
        _rootView.layer.masksToBounds = YES;
    }
    return _rootView;
}

- (UIButton *)defaultStatusBtn {
    if (!_defaultStatusBtn) {
        UIButton *statusBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        statusBtn.backgroundColor = [UIColor colorWithRed:255/255.0 green:90/255.0 blue:95/255.0 alpha:1];
        [statusBtn setTitle:@"直播中" forState:UIControlStateNormal];
        [statusBtn setImage:SuperPlayerImage(@"LiveWindow_tip") forState:UIControlStateNormal];
        [statusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        statusBtn.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
        statusBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 3.5, 0, 0);
        _defaultStatusBtn = statusBtn;
    }
    return _defaultStatusBtn;
}

- (UIButton *)defaultCloseBtn {
    if (!_defaultCloseBtn) {
        _defaultCloseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _defaultCloseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_defaultCloseBtn setImage:SuperPlayerImage(@"close") forState:UIControlStateNormal];
        [_defaultCloseBtn addTarget:self action:@selector(closeBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        _defaultCloseBtn.hidden = YES;
        _defaultCloseBtn.backgroundColor = [UIColor colorWithRed:0/255.0 green:0/255.0 blue:0/255.0 alpha:0.2];
        _defaultCloseBtn.layer.cornerRadius = 10;
    }
    return _defaultCloseBtn;
}

- (UIVisualEffectView *)effectView {
    if (!_effectView) {
        UIBlurEffect *blurEffect =[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        _effectView =[[UIVisualEffectView alloc]initWithEffect:blurEffect];
        
    }
    return _effectView;
}
- (UIImageView *)centerImage {
    if (!_centerImage) {
        _centerImage = [[UIImageView alloc] initWithImage:self.superPlayer.coverImageView.image];
        _centerImage.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _centerImage;
}


@end
