//
//  SuperPlayerSmallView.h
//  SuperPlayer
//
//  Created by Mac on 2021/4/23.
//

#import <UIKit/UIKit.h>

@class SuperPlayerView;

typedef void(^SuperPlayerWindowEventHandler)(void);

typedef NS_ENUM(NSInteger, UHSmallWindowType) {
    UHSmallWindowTypeLive,
    UHSmallWindowTypeVod,
};

NS_ASSUME_NONNULL_BEGIN

@interface SuperPlayerSmallView : UIView

@property (nonatomic ,strong)UIViewController *baseVC;
/// 显示小窗
- (void)showWithVC:(UIViewController *)vc;
/// 隐藏小窗
- (void)hide;
/// 单例
+ (instancetype)sharedInstance;

@property (nonatomic, assign) UHSmallWindowType windowType;

@property (nonatomic,copy) SuperPlayerWindowEventHandler backHandler;
@property (nonatomic,copy) SuperPlayerWindowEventHandler closeHandler;  // 默认关闭
/// 小窗播放器
@property (nonatomic,weak) SuperPlayerView *superPlayer;
/// 点击小窗返回的controller
@property UIViewController *backController;
/// 小窗是否显示
@property (readonly) BOOL isShowing;  //

/// 小窗底部状态按钮title
@property (nonatomic ,copy) NSString *statusBtntitle;
/// 关闭按钮延迟多少秒显示   默认 0
@property (nonatomic ,assign) NSInteger closeBtnAfterTime;

@property (nonatomic, assign) CGRect floatViewRect;

@property (nonatomic, assign) BOOL hideStatus;
@property (nonatomic, assign) BOOL hideClose;

@property (nonatomic, weak) UIView *customView;
@property (nonatomic, strong) UIButton *defaultCloseBtn;
@property (nonatomic, strong) UIButton *defaultStatusBtn;
/// 小窗主view
@property (nonatomic, strong) UIView *rootView;


@end

NS_ASSUME_NONNULL_END
