#import <UIKit/UIKit.h>
#import "SuperPlayer.h"
#import "SuperPlayerModel.h"
#import "SuperPlayerViewConfig.h"

@class SuperPlayerControlView;
@class SuperPlayerView;

@protocol SuperPlayerDelegate <NSObject>
@optional
/// 返回事件
- (void)superPlayerBackAction:(SuperPlayerView *)player;
/// 全屏改变通知
- (void)superPlayerFullScreenChanged:(SuperPlayerView *)player;
/// 播放开始通知
- (void)superPlayerDidStart:(SuperPlayerView *)player;
/// 播放结束通知
- (void)superPlayerDidEnd:(SuperPlayerView *)player;
/// 正在加载
- (void)superPlayerLoading:(SuperPlayerView *)player;
/// 结束加载
- (void)superPlayerLoadingEnd:(SuperPlayerView *)player;
/// 播放错误通知
- (void)superPlayerError:(SuperPlayerView *)player errCode:(int)code errMessage:(NSString *)why;
// 需要通知到父view的事件在此添加
/// 点击事件
- (void)superPlayerSingleTap:(SuperPlayerView *)player;

@end

/// 播放器的状态
typedef NS_ENUM(NSInteger, SuperPlayerState) {
    StateFailed,     // 播放失败
    StateBuffering,  // 缓冲中
    StatePrepare,    // 准备就绪
    StatePlaying,    // 播放中
    StateStopped,    // 停止播放
    StatePause,      // 暂停播放
    StateFirstFrame, // 第一帧画面
};


/// 播放器布局样式
typedef NS_ENUM(NSInteger, SuperPlayerLayoutStyle) {
    SuperPlayerLayoutStyleCompact, ///< 精简模式
    SuperPlayerLayoutStyleFullScreen ///< 全屏模式
};

@interface SuperPlayerView : UIView

/** 设置代理 */
@property (nonatomic, weak) id<SuperPlayerDelegate> delegate;

@property (nonatomic, assign) SuperPlayerLayoutStyle layoutStyle;

/// 播放器标识
@property (nonatomic, copy) NSString *identifier;

/// 设置播放器的父view。播放过程中调用可实现播放窗口转移
@property (nonatomic, weak) UIView *fatherView;
/// 播放acc加速流
@property (nonatomic, assign) BOOL playAccURL;
/// 播放器的状态
@property (nonatomic, assign) SuperPlayerState state;
/// 是否全屏
@property (nonatomic, assign, setter=setFullScreen:) BOOL isFullScreen;
/// 是否垂直全屏
@property (nonatomic, assign, setter=setVFullScreen:) BOOL isVFullScreen;
/// 是否锁定旋转
@property (nonatomic, assign) BOOL isLockScreen;
/// 是否是直播流
@property (readonly) BOOL isLive;
/// 在后台是否自动暂停
@property (nonatomic, assign) BOOL autoPauseInBackground;
/// 超级播放器控制层
@property (nonatomic) SuperPlayerControlView *controlView;
/// 是否允许竖屏手势
@property (nonatomic) BOOL disableGesture;
/// 是否允许点击手势
@property (nonatomic) BOOL disableTapGesture;
/// 是否在手势中
@property (readonly)  BOOL isDragging;
/// 是否加载成功
@property (readonly)  BOOL  isLoaded;
/// 自定义背景色，默认为黑色
@property (nonatomic, strong) UIColor *customBackgroundColor;
/// 是否禁用网络监测
@property (nonatomic, assign) BOOL disableNetWatcher;
/// 是否隐藏fastView
@property (nonatomic, assign) BOOL hiddenFastView;
/// 设置封面图片
@property (nonatomic) UIImageView *coverImageView;
/// 设置清晰封面图片
@property (nonatomic) UIImageView *coverCenterImageView;
/// 重播按钮
@property (nonatomic, strong) UIButton *repeatBtn;
/// 全屏退出
@property (nonatomic, strong) UIButton *repeatBackBtn;
/// 是否自动播放（在playWithModel前设置)
@property BOOL autoPlay;
/// 视频总时长
@property (nonatomic) CGFloat playDuration;
/// 视频当前播放时间
@property (nonatomic) CGFloat playCurrentTime;
/// 起始播放时间，用于从上次位置开播
@property CGFloat startTime;
/// 播放的视频Model
@property (readonly) SuperPlayerModel       *playerModel;
/// 播放器配置
@property SuperPlayerViewConfig *playerConfig;
/// 循环播放
@property (nonatomic) BOOL loop;
/// 开始播放后是否自动隐藏控制区
@property (nonatomic, assign) BOOL disableAutoHideControl;
/// 自动调整渲染模式
@property (nonatomic, assign) BOOL autoAdjustRenderMode;
/// 播放器背景色
@property (nonatomic, strong) UIColor *playerBackgroundColor;

/// 播放器加载中视图
@property (nonatomic ,weak) UIImageView *xxloadImage;

/// 字幕数据源
@property (nonatomic ,strong) NSMutableArray *subtitlesArray;

/**
 * 视频雪碧图
 */
@property TXImageSprite *imageSprite;
/**
 * 打点信息
 */
@property NSArray *keyFrameDescList;
/**
 * 播放model
 */
- (void)playWithModel:(SuperPlayerModel *)playerModel;

/**
 * 重置player
 */
- (void)resetPlayer;

/**
 * 播放
 */
- (void)resume;

/**
 * 暂停
 * @warn isLoaded == NO 时暂停无效
 */
- (void)pause;

/**
 *  从xx秒开始播放视频跳转
 *
 *  @param dragedSeconds 视频跳转的秒数
 */
- (void)seekToTime:(NSInteger)dragedSeconds;

/**
 *  增加字幕控件
 *
 *  @param tagView 字幕控件位置的参照view
 */
- (void)addSubtitleViewWithTagView:(UIView *)tagView;

- (void)changeSubtitlesData:(NSMutableArray *)subtitles;

@property (nonatomic ,assign)BOOL isHideSubtitles;
@end
