//
//  SuperPlayerSmallView.h
//  SuperPlayer
//
//  Created by Mac on 2021/4/23.
//

#import <UIKit/UIKit.h>

@class SuperPlayerView;

typedef void(^SuperPlayerWindowEventHandler)(void);

NS_ASSUME_NONNULL_BEGIN

@interface SuperPlayerSmallView : UIView


/// 显示小窗
- (void)show;
/// 隐藏小窗
- (void)hide;
/// 单例
+ (instancetype)sharedInstance;

@property (nonatomic,copy) SuperPlayerWindowEventHandler backHandler;
@property (nonatomic,copy) SuperPlayerWindowEventHandler closeHandler;  // 默认关闭
/// 小窗播放器
@property (nonatomic,weak) SuperPlayerView *superPlayer;
/// 小窗主view
@property (readonly) UIView *rootView;
/// 点击小窗返回的controller
@property UIViewController *backController;
/// 小窗是否显示
@property (readonly) BOOL isShowing;  //

/// 小窗底部状态按钮title
@property (nonatomic ,copy) NSString *statusBtntitle;

/// 关闭按钮延迟多少秒显示   默认 0
@property (nonatomic ,assign) NSInteger closeBtnAfterTime;

@property (nonatomic, assign) CGRect floatViewRect;

@property (nonatomic, weak) UIView *customView;

@end

NS_ASSUME_NONNULL_END
