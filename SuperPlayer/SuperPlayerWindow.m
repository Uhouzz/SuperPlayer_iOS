//
//  SuperPlayerWindow.m
//  TXLiteAVDemo
//
//  Created by annidyfeng on 2018/6/26.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "SuperPlayerWindow.h"
#import "SuperPlayer.h"
#import "SuperPlayerView+Private.h"
#import "UIView+MMLayout.h"
#import "DataReport.h"
#import "UIView+Fade.h"

#define FLOAT_VIEW_WIDTH  200
#define FLOAT_VIEW_HEIGHT 112

@interface SuperPlayerWindow()<TXVodPlayListener>
@property (weak) UIView *origFatherView;
@property (nonatomic, assign) BOOL hiddenfastView;
@end

@implementation SuperPlayerWindow {
    UIView *_rootView;
    UIButton    *_closeBtn;
    UIButton    *_backBtn;
    UIButton    *_statusBtn;
}

+ (instancetype)sharedInstance {
    static SuperPlayerWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SuperPlayerWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    self.windowLevel = UIWindowLevelStatusBar - 1;
    self.rootViewController = [UIViewController new];
    self.rootViewController.view.backgroundColor = [UIColor clearColor];
    self.rootViewController.view.userInteractionEnabled = NO;
    
    //设置默认显示关闭按钮的延迟
    self.closeBtnAfterTime = 0;
    
    _rootView = [[UIView alloc] initWithFrame:CGRectZero];
    _rootView.backgroundColor = [UIColor blackColor];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizer:)];
    [_rootView addGestureRecognizer:panGesture];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeBtn setImage:SuperPlayerImage(@"close") forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    closeBtn.hidden = YES;
    closeBtn.backgroundColor = [UIColor colorWithRed:0/255.0 green:0/255.0 blue:0/255.0 alpha:0.2];
    closeBtn.layer.cornerRadius = 10;
    _rootView.layer.masksToBounds = YES;
    UIButton *statusBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    statusBtn.layer.cornerRadius = 12;
    statusBtn.layer.masksToBounds = YES;
    [_rootView addSubview:closeBtn];
    [closeBtn sizeToFit];
    _closeBtn = closeBtn;
    
    
//    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
//    backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
//    [backBtn setImage:SuperPlayerImage(@"fullscreen") forState:UIControlStateNormal];
//    [backBtn addTarget:self action:@selector(backBtnClick:) forControlEvents:UIControlEventTouchUpInside];
//    [_rootView addSubview:backBtn];
//    [backBtn sizeToFit];
//    _backBtn = backBtn;
    
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
        _closeBtn.hidden = NO;
    });
}

- (void)setStatusBtntitle:(NSString *)statusBtntitle{
    _statusBtntitle = statusBtntitle;
    [_statusBtn setTitle:statusBtntitle forState:UIControlStateNormal];
}
- (void)show {
    _rootView.frame = self.floatViewRect;
    [self addSubview:_rootView];
    self.hidden = NO;
    
    self.origFatherView = self.superPlayer.fatherView;
    self.hiddenfastView = self.superPlayer.hiddenFastView;
    if (self.origFatherView != _rootView) {
        self.superPlayer.fatherView = _rootView;
    }
    self.superPlayer.hiddenFastView = YES;
    [self.superPlayer.controlView fadeOut:0.01];
    
    [_rootView bringSubviewToFront:_backBtn];
    [_rootView bringSubviewToFront:_closeBtn];
    if (self.customView) {
        [_rootView bringSubviewToFront:self.customView];
    }
    _closeBtn.mm_width(20).mm_height(20).mm_top(6).mm_right(6);
    
    _isShowing = YES;
    
    _rootView.layer.cornerRadius = 8;
       //给图层添加一个有色边框
    _rootView.layer.borderWidth = 1;
    
    _rootView.layer.borderColor = [UIColor colorWithRed:255/255.0 green:90/255.0 blue:95/255.0 alpha:1].CGColor;
    _rootView.layer.masksToBounds = YES;
    UIButton *statusBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    statusBtn.backgroundColor = [UIColor colorWithRed:255/255.0 green:90/255.0 blue:95/255.0 alpha:1];
    [statusBtn setTitle:@"直播中" forState:UIControlStateNormal];
    [statusBtn setImage:SuperPlayerImage(@"LiveWindow_tip") forState:UIControlStateNormal];
    [statusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    statusBtn.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
    statusBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 3.5, 0, 0);
    [_rootView addSubview:statusBtn];
    statusBtn.mm_width(61).mm_height(24).mm_left(0).mm_bottom(0);
    UIBezierPath *maskPath= [UIBezierPath bezierPathWithRoundedRect:statusBtn.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight | UIRectCornerBottomRight cornerRadii:CGSizeMake(12, 8)];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = statusBtn.bounds;
    maskLayer.path = maskPath.CGPath;
    statusBtn.layer.mask = maskLayer;
    _statusBtn = statusBtn;
    [self setCloseBtnAfterShow:self.closeBtnAfterTime];
    [DataReport report:@"floatmode" param:nil];
}

- (void)hide {
    self.floatViewRect = _rootView.frame;
    
    [_rootView removeFromSuperview];
    self.hidden = YES;
    
    self.superPlayer.hiddenFastView = self.hiddenfastView;
    self.superPlayer.fatherView = self.origFatherView;
    
    _isShowing = NO;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (CGRectContainsPoint(_rootView.bounds,
                            [_rootView convertPoint:point fromView:self])) {
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
        
        CGPoint center = _rootView.center;
        center.x += translation.x;
        center.y += translation.y;
        _rootView.center = center;
        
        UIEdgeInsets effectiveEdgeInsets = UIEdgeInsetsZero; // 边距可以自己调
        
        CGFloat   leftMinX = 0.0f + effectiveEdgeInsets.left;
        CGFloat    topMinY = 0.0f + effectiveEdgeInsets.top;
        CGFloat  rightMaxX = self.bounds.size.width - _rootView.bounds.size.width + effectiveEdgeInsets.right;
        CGFloat bottomMaxY = self.bounds.size.height - _rootView.bounds.size.height + effectiveEdgeInsets.bottom;
        
        CGRect frame = _rootView.frame;
        frame.origin.x = frame.origin.x > rightMaxX ? rightMaxX : frame.origin.x;
        frame.origin.x = frame.origin.x < leftMinX ? leftMinX : frame.origin.x;
        frame.origin.y = frame.origin.y > bottomMaxY ? bottomMaxY : frame.origin.y;
        frame.origin.y = frame.origin.y < topMinY ? topMinY : frame.origin.y;
        _rootView.frame = frame;
        
        // zero
        [panGesture setTranslation:CGPointZero inView:self];
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


@end
