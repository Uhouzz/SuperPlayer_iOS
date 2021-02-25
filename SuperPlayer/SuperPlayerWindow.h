//
//  SuperPlayerWindow.h
//  TXLiteAVDemo
//
//  Created by annidyfeng on 2018/6/26.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SuperPlayerView;

typedef void(^SuperPlayerWindowEventHandler)(void);

/// 播放器小窗Window
@interface SuperPlayerWindow : UIWindow

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

@property (nonatomic, assign) CGRect floatViewRect;

@property (nonatomic, weak) UIView *customView;

/// 延迟显示关闭按钮
/// @param time 秒
- (void)setCloseBtnAfterShow:(NSInteger)time;

/// 设置小窗底部状态title
- (void)setLiveStatusTitle:(NSString *)title;
@end
