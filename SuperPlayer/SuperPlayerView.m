#import "SuperPlayerView.h"
#import <AVFoundation/AVFoundation.h>
#import "SuperPlayer.h"
#import "SuperPlayerControlViewDelegate.h"
#import "J2Obj.h"
#import "SuperPlayerView+Private.h"
#import "DataReport.h"
#import "TXCUrl.h"
#import "StrUtils.h"
#import "SPBundleUtil.h"
#import "UIView+Fade.h"
#import "TXBitrateItemHelper.h"
#import "UIView+MMLayout.h"
#import "SPDefaultControlView.h"
#import "SuperPlayerSubtitlesView.h"
static UISlider * _volumeSlider;

#define CellPlayerFatherViewTag  200

//忽略编译器的警告
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"



@interface SuperPlayerView () <TXLiveBaseDelegate,TXLivePlayListener,TXVodPlayListener>
@property (nonatomic ,strong) SuperPlayerSubtitlesView *subtitlesView;
@property (nonatomic ,strong) UIView *tagView;


@end
@implementation SuperPlayerView {
    UIView *_fullScreenBlackView;
    SuperPlayerControlView *_controlView;
    NSString               *_currentVideoUrl;
    BOOL                   _isPrepare;
}


#pragma mark - life Cycle

/**
 *  代码初始化调用此方法
 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self initializeThePlayer]; }
    return self;
}

/**
 *  storyboard、xib加载playerView会调用此方法
 */
- (void)awakeFromNib {
    [super awakeFromNib];
    [self initializeThePlayer];
}

/**
 *  初始化player
 */
- (void)initializeThePlayer {
    LOG_ME;


    
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (!window.isHidden) {
            [window addSubview:self.volumeView];
            break;
        }
    }
    _fullScreenBlackView = [UIView new];
    _fullScreenBlackView.backgroundColor = [UIColor blackColor];

    // 单例slider
    _volumeSlider = nil;
    for (UIView *view in [self.volumeView subviews]) {
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]) {
            _volumeSlider = (UISlider *)view;
            break;
        }
    }

    _playerConfig = [[SuperPlayerViewConfig alloc] init];
    
    // 添加通知
    [self addNotifications];
    // 添加手势
    [self createGesture];
    
    self.autoPlay = YES;
    self.autoPauseInBackground = YES;
}

- (void)addSubtitleViewWithTagView:(UIView *)tagView {
    if (self.subtitlesView) {
        [self.subtitlesView removeFromSuperview];
        self.subtitlesView = nil;
    }
    self.subtitlesView = [[SuperPlayerSubtitlesView alloc] init];
    [self insertSubview:self.subtitlesView belowSubview:self.controlView];
    self.tagView = tagView;
    [self.subtitlesView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.mas_equalTo(self.tagView.mas_top).offset(-10);
        make.centerX.mas_equalTo(self);
        make.width.mas_lessThanOrEqualTo(300);
    }];
}
- (void)dealloc {
    LOG_ME;
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

    [self reportPlay];
    [self.netWatcher stopWatch];
    [self.volumeView removeFromSuperview];
    
    if (_vodPlayer) {
        [_vodPlayer stopPlay];
        [_vodPlayer removeVideoWidget];
        _vodPlayer = nil;
    }
}

#pragma mark - 观察者、通知

/**
 *  添加观察者、通知
 */
- (void)addNotifications {
    // app退到后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    // app进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayground:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    // 监测设备方向
//    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(onDeviceOrientationChange)
//                                                 name:UIDeviceOrientationDidChangeNotification
//                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onStatusBarOrientationChange)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];
}

#pragma mark - layoutSubviews

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.subviews.count > 0) {
        UIView *innerView = self.subviews[0];
        if ([innerView isKindOfClass:NSClassFromString(@"TXIJKSDLGLView")] || [innerView isKindOfClass:NSClassFromString(@"TXCAVPlayerView")] || [innerView isKindOfClass:NSClassFromString(@"TXCThumbPlayerView")]) {
            innerView.frame = self.bounds;
            innerView.backgroundColor = self.playerBackgroundColor ? : [UIColor blackColor];
        }
    }
}

#pragma mark - Public Method

- (void)playWithModel:(SuperPlayerModel *)playerModel {
    LOG_ME;
    _playerModel = playerModel;
    [self setChildViewState];
    
    self.isShiftPlayback = NO;
    [self reportPlay];
    self.reportTime = [NSDate date];
    [self _removeOldPlayer];
    [self _playWithModel:playerModel];
    self.repeatBtn.hidden = YES;
    self.repeatBackBtn.hidden = YES;
}
- (void)reloadModel {
    SuperPlayerModel *model = _playerModel;
    if (model) {
        [self resetPlayer];
        [self _playWithModel:_playerModel];
        [self addNotifications];
    }
}

- (void)_playWithModel:(SuperPlayerModel *)playerModel {
    _currentVideoUrl = nil;
    [self configTXPlayer];
}

/**
 *  player添加到fatherView上
 */
- (void)addPlayerToFatherView:(UIView *)view {
    [self removeFromSuperview];
    if (view) {
        [view addSubview:self];
        [self mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_offset(UIEdgeInsetsZero);
        }];
    }
}

- (void)setFatherView:(UIView *)fatherView {
    if (fatherView != _fatherView) {
        [self addPlayerToFatherView:fatherView];
    }
    _fatherView = fatherView;
}

/**
 *  重置player
 */
- (void)resetPlayer {
    LOG_ME;
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 暂停
    [self pause];
    
    [self.vodPlayer stopPlay];
    [self.vodPlayer removeVideoWidget];
    self.vodPlayer = nil;
    
    [self.livePlayer stopPlay];
    [self.livePlayer removeVideoWidget];
    self.livePlayer = nil;
    
    [self reportPlay];
    
    self.state = StateStopped;
}

/**
 *  播放
 */
- (void)resume {
    LOG_ME;
    [self.controlView setPlayState:YES];
    self.isPauseByUser = NO;
    if (self.isLive) {
        self.state         = StatePlaying;
        [_livePlayer resume];
    } else {
        if (!self.disableAutoHideControl) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(controlViewFadeOut) object:nil];
            [self performSelector:@selector(controlViewFadeOut) withObject:nil afterDelay:2.5];
        }
        if (self.state == StatePause || self.state == StateBuffering) {
            [self.vodPlayer resume];
            self.state = StatePlaying;
        } else if (self.state == StatePlaying) {
            [self.spinner stopAnimating];
        } else {
            if (self.state == StatePrepare) {
                self.state         = StatePlaying;
                [self.vodPlayer resume];
            } else {
                _isPrepare = YES;
            }
        }
    }
}

/**
 * 暂停
 */
- (void)pause {
    LOG_ME;
    if (!self.isLoaded) return;
    if (self.playDidEnd) return;
    self.repeatBtn.hidden     = YES;
    [self.controlView setPlayState:NO];
    self.isPauseByUser = YES;
    self.state         = StatePause;
    if (self.isLive) {
        [_livePlayer pause];
    } else {
        [self.controlView fadeShow];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(controlViewFadeOut) object:nil];
        [self.vodPlayer pause];
        
    }
}

- (void)removeVideo {
    _isPrepare = NO;
    self.state = StateStopped;
    [self.vodPlayer stopPlay];
    [self.vodPlayer removeVideoWidget];
}


#pragma mark - Control View Configuration
- (void)resetControlViewWithLive:(BOOL)isLive shiftPlayback:(BOOL)isShiftPlayback isPlaying:(BOOL)isPlaying {
    [_controlView playerBegin:self.playerModel isLive:isLive isTimeShifting:isShiftPlayback isAutoPlay:isPlaying];
}

/**
 *  设置Player相关参数
 */
- (void)configTXPlayer {
    LOG_ME;
    self.backgroundColor = self.customBackgroundColor ? : [UIColor blackColor];
    
    if (_playerConfig.enableLog) {
        [TXLiveBase setLogLevel:LOGLEVEL_DEBUG];
        [TXLiveBase sharedInstance].delegate = self;
        [TXLiveBase setConsoleEnabled:YES];
    }
    
    [self.vodPlayer stopPlay];
    [self.livePlayer stopPlay];
    [self.vodPlayer removeVideoWidget];
    [self.livePlayer removeVideoWidget];
    _vodPlayer = nil;

    self.liveProgressTime = self.maxLiveProgressTime = 0;
    
    // 如果videoUrl存在，则是直播
    int liveType = -1;
    if (self.playerModel.videoURL && self.playerModel.videoURL.length > 0) {
        liveType = [self livePlayerType];
        if (liveType >= 0) {
            self.isLive = YES;
        } else {
            self.isLive = NO;
        }
    } else {
        self.isLive = NO;
    }

    self.isLoaded = NO;

    self.netWatcher.playerModel = self.playerModel;
    if (self.isLive) {
        if (!self.livePlayer) {
            self.livePlayer          = [[TXLivePlayer alloc] init];
            self.livePlayer.delegate = self;
        }
        [self setLivePlayerConfig];
        [self.controlView setProgressTime:0 totalTime:-1 progressValue:1 playableValue:0];
        [self.livePlayer startLivePlay:self.playerModel.videoURL type:liveType];
        _currentVideoUrl = self.playerModel.videoURL;
        TXCUrl *curl = [[TXCUrl alloc] initWithString:self.playerModel.videoURL];
    } else {
        
        [self setVodPlayConfig];
        
        NSString *videoUrlStr = _playerModel.videoURL;
        if (videoUrlStr && videoUrlStr.length > 0) {
            [self preparePlayWithUrl:videoUrlStr];
        } else {
            NSArray *multiVideoURLs = _playerModel.multiVideoURLs;
            if (multiVideoURLs.count > 0 && multiVideoURLs.firstObject) {
                SuperPlayerUrl *videoUrl = multiVideoURLs.firstObject;
                if (videoUrl.url && videoUrl.url.length > 0) {
                    [self preparePlayWithUrl:videoUrl.url];
                } else {
                    TXPlayerAuthParams *params = [[TXPlayerAuthParams alloc] init];
                    params.appId = (int)_playerModel.appId;
                    params.fileId = _playerModel.videoId.fileId;
                    params.sign = _playerModel.videoId.psign;
                    [self preparePlayWithVideoParams:params];
                }
            } else {
                TXPlayerAuthParams *params = [[TXPlayerAuthParams alloc] init];
                params.appId = (int)_playerModel.appId;
                params.fileId = _playerModel.videoId.fileId;
                params.sign = _playerModel.videoId.psign;
                [self preparePlayWithVideoParams:params];
            }
        }
    }
    [self resetControlViewWithLive:self.isLive shiftPlayback:self.isShiftPlayback isPlaying:self.state == StatePlaying ? YES : NO];
    self.controlView.playerConfig = self.playerConfig;
    self.repeatBtn.hidden         = YES;
    self.playDidEnd               = NO;
    [self.middleBlackBtn fadeOut:0.1];
    self.coverImageView.backgroundColor = self.playerBackgroundColor ? : [UIColor blackColor];

}

- (void)setVodPlayConfig {
    TXVodPlayConfig *config    = [[TXVodPlayConfig alloc] init];
    config.smoothSwitchBitrate = YES;
    config.progressInterval = 0.02;
    config.headers = self.playerConfig.headers;
    config.keepLastFrameWhenStop = YES;

//    config.overlayIv = self.playerModel.overlayIv;
//    config.overlayKey = self.playerModel.overlayKey;
    config.preferredResolution = 720 * 1280;
    [self.vodPlayer setConfig:config];
   
//    self.vodPlayer.token    = self.playerModel.drmToken;
    self.vodPlayer.enableHWAcceleration = self.playerConfig.hwAcceleration;
    [self.vodPlayer setStartTime:self.startTime];
    self.startTime = 0;
    
    [self.vodPlayer setupVideoWidget:self insertIndex:0];
    [self.vodPlayer setRate:self.playerConfig.playRate];
    [self.vodPlayer setMirror:self.playerConfig.mirror];
    [self.vodPlayer setMute:self.playerConfig.mute];
    [self.vodPlayer setRenderMode:self.playerConfig.renderMode];
    [self.vodPlayer setLoop:self.loop];
    
    [self.netWatcher startWatch];
    __weak SuperPlayerView *weakSelf = self;
    [self.netWatcher setNotifyTipsBlock:^(NSString *msg) {
        SuperPlayerView *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf showMiddleBtnMsg:msg withAction:ActionSwitch];
            [strongSelf.middleBlackBtn fadeOut:2];
        }
    }];
}

- (void)setLivePlayerConfig {
    TXLivePlayConfig *config      = [[TXLivePlayConfig alloc] init];
    config.bAutoAdjustCacheTime = self.playerConfig.bAutoAdjustCacheTime;
    config.maxAutoAdjustCacheTime = self.playerConfig.maxAutoAdjustCacheTime;
    config.minAutoAdjustCacheTime = self.playerConfig.minAutoAdjustCacheTime;
    config.headers                = self.playerConfig.headers;
    [self.livePlayer setConfig:config];
    
    self.livePlayer.enableHWAcceleration = self.playerConfig.hwAcceleration;
    [self.livePlayer setupVideoWidget:CGRectZero containView:self insertIndex:0];
    [self.livePlayer setMute:self.playerConfig.mute];
    [self.livePlayer setRenderMode:self.playerConfig.renderMode];
    self.isPauseByUser = NO;
    
    [self.netWatcher startWatch];
    __weak SuperPlayerView *weakSelf = self;
    [self.netWatcher setNotifyTipsBlock:^(NSString *msg) {
        SuperPlayerView *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf showMiddleBtnMsg:msg withAction:ActionSwitch];
            [strongSelf.middleBlackBtn fadeOut:2];
        }
    }];
}

- (void)preparePlayVideo {
    [self.controlView setProgressTime:0 totalTime:_playerModel.duration progressValue:0 playableValue:0 / _playerModel.duration];
    if (_playerModel.action == PLAY_ACTION_AUTO_PLAY) {
        [self.controlView setPlayState:YES];
        self.isPauseByUser = NO;

    } else if (_playerModel.action == PLAY_ACTION_PRELOAD) {
        self.vodPlayer.isAutoPlay = NO;

        self.isPauseByUser = YES;
        [self.controlView setPlayState:NO];
    } else {
        self.isPauseByUser = YES;
        [self.controlView setPlayState:NO];
    }
}

- (void)preparePlayWithVideoParams:(TXPlayerAuthParams *)params {
    [self preparePlayVideo];
    if (_playerModel.action == PLAY_ACTION_AUTO_PLAY || _playerModel.action == PLAY_ACTION_PRELOAD) {
        [self.vodPlayer startVodPlayWithParams:params];
    }
}

- (void)preparePlayWithUrl:(NSString *)videoUrl {
    _currentVideoUrl = videoUrl;
    [self preparePlayVideo];
    if (_playerModel.action == PLAY_ACTION_AUTO_PLAY || _playerModel.action == PLAY_ACTION_PRELOAD) {
        [self.vodPlayer startVodPlay:videoUrl];
    }
}

- (void)startPlay {
    if (_currentVideoUrl) {
        [self.vodPlayer startVodPlay:_currentVideoUrl];
    } else {
        TXPlayerAuthParams *params = [[TXPlayerAuthParams alloc] init];
        params.appId = (int)_playerModel.appId;
        params.fileId = _playerModel.videoId.fileId;
        params.sign = _playerModel.videoId.psign;
        [self.vodPlayer startVodPlayWithParams:params];
    }
}

- (void)restart {
    [self.spinner startAnimating];

    self.repeatBtn.hidden = YES;
    self.repeatBackBtn.hidden = YES;
    self.playDidEnd = NO;
    [self.middleBlackBtn fadeOut:0.1];
    
    [self.controlView setProgressTime:0 totalTime:self.vodPlayer.duration progressValue:0 playableValue:0 / self.vodPlayer.duration];

    if ([self.vodPlayer supportedBitrates].count > 1) {
        [self.vodPlayer resume];
    } else {
        [self startPlay];
        if (_playerModel.action == PLAY_ACTION_PRELOAD) {
            [self resume];
        }
    }
}

- (void)controllViewPlayClick {
    [self.spinner startAnimating];
    if (!self.vodPlayer.isAutoPlay) {
        [self resume];
    } else {
        if (self.state == StateStopped) {
            [self.controlView setPlayState:YES];
            self.isPauseByUser = NO;
            [self startPlay];
        } else {
            [self resume];
        }
    }
}

/**
 *  创建手势
 */
- (void)createGesture {
    // 单击
    self.singleTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(singleTapAction:)];
    self.singleTap.delegate                = self;
    self.singleTap.numberOfTouchesRequired = 1; //手指数
    self.singleTap.numberOfTapsRequired    = 1;
    [self addGestureRecognizer:self.singleTap];
    
    // 双击(播放/暂停)
    self.doubleTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTapAction:)];
    self.doubleTap.delegate                = self;
    self.doubleTap.numberOfTouchesRequired = 1; //手指数
    self.doubleTap.numberOfTapsRequired    = 2;
    [self addGestureRecognizer:self.doubleTap];

    // 解决点击当前view时候响应其他控件事件
    [self.singleTap setDelaysTouchesBegan:YES];
    [self.doubleTap setDelaysTouchesBegan:YES];
    // 双击失败响应单击事件
    [self.singleTap requireGestureRecognizerToFail:self.doubleTap];
    
    // 加载完成后，再添加平移手势
    // 添加平移手势，用来控制音量、亮度、快进快退
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panDirection:)];
    panRecognizer.delegate = self;
    [panRecognizer setMaximumNumberOfTouches:1];
    [panRecognizer setDelaysTouchesBegan:YES];
    [panRecognizer setDelaysTouchesEnded:YES];
    [panRecognizer setCancelsTouchesInView:YES];
    [self addGestureRecognizer:panRecognizer];
}

- (void)detailPrepareState {
    // 防止暂停导致加载进度不消失
    if (self.isPauseByUser) [self.spinner stopAnimating];
    self.state = StatePrepare;
    if (self->_isPrepare) {
        [self.vodPlayer resume];
        self->_isPrepare = NO;
        self.isPauseByUser = NO;
        [self.controlView setPlayState:YES];
    }
}

- (void)detailProgress {
    // StateStopped 是当前播放的状态  playDidEnd 是否播放完了
    // StatePrepare 是在接受到onPlayEvent回调的状态  _isPrepare是用户主动触发resume的状态
    if (self.state == StateStopped) return;
    if (self.playDidEnd) return;
    if (_playerModel.action == PLAY_ACTION_PRELOAD) {
        // 预加载状态下才会有此判断
        if (self.state == StatePrepare || !self->_isPrepare) {
            return;
        };
    }
    
    if (self.state == StatePlaying) {
        self.repeatBtn.hidden = YES;
        self.playDidEnd = NO;
    }
}

- (void)detailPlayerEvent:(TXVodPlayer *)player event:(int)evtID param:(NSDictionary *)param{
    if (evtID == PLAY_ERR_NET_DISCONNECT) {
        [self showMiddleBtnMsg:kStrBadNetRetry withAction:ActionContinueReplay];
    } else {
        [self showMiddleBtnMsg:kStrLoadFaildRetry withAction:ActionRetry];
    }
    self.state = StateFailed;
    [player stopPlay];
    if ([self.delegate respondsToSelector:@selector(superPlayerError:errCode:errMessage:)]) {
        [self.delegate superPlayerError:self errCode:evtID errMessage:param[EVT_MSG]];
    }
}

- (void)setChildViewState {
    [self.controlView setOrientationPortraitConstraint];
    self.isShiftPlayback  = NO;
    self.state         = StateStopped;
    [self reportPlay];
    self.reportTime = [NSDate date];
    [self _removeOldPlayer];
    if (_playerModel.action == PLAY_ACTION_AUTO_PLAY) {
        self.state         = StateBuffering;
        [self.spinner startAnimating];
    }
    
    self.repeatBtn.hidden     = YES;
    // 播放时添加监听
    [self addNotifications];
}

- (void)prepareAutoplay {
    if (!self.autoPlay) {
        self.autoPlay = YES; // 下次用户设置自动播放失效
        [self pause];
    }
    
    if ([self.delegate respondsToSelector:@selector(superPlayerDidStart:)]) {
        [self.delegate superPlayerDidStart:self];
    }
}


#pragma mark - KVO

- (UIDeviceOrientation)_orientationForFullScreen:(BOOL)fullScreen {
    UIDeviceOrientation targetOrientation = [UIDevice currentDevice].orientation;
    if (fullScreen) {
        if (!UIDeviceOrientationIsLandscape(targetOrientation)) {
            targetOrientation = UIDeviceOrientationLandscapeLeft;
        }
    } else {
        if (!UIDeviceOrientationIsPortrait(targetOrientation)) {
            targetOrientation = UIDeviceOrientationPortrait;
        }
    //    targetOrientation = (UIDeviceOrientation)[UIApplication sharedApplication].statusBarOrientation;
    }
    return targetOrientation;
}

- (void)_switchToFullScreen:(BOOL)fullScreen {
    if (_isFullScreen == fullScreen) {
        return;
    }
    _isFullScreen = fullScreen;
    [self.fatherView.mm_viewController setNeedsStatusBarAppearanceUpdate];

    UIDeviceOrientation targetOrientation = [self _orientationForFullScreen:fullScreen];// [UIDevice currentDevice].orientation;

    if (fullScreen) {
        [self removeFromSuperview];
        [[UIApplication sharedApplication].keyWindow addSubview:_fullScreenBlackView];
        [_fullScreenBlackView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@(ScreenHeight));
            make.height.equalTo(@(ScreenWidth));
            make.center.equalTo([UIApplication sharedApplication].keyWindow);
        }];

        [[UIApplication sharedApplication].keyWindow addSubview:self];
        [self mas_remakeConstraints:^(MASConstraintMaker *make) {
            if (IsIPhoneX) {
                make.width.equalTo(@(ScreenHeight - self.mm_safeAreaTopGap * 2));
            } else {
                make.width.equalTo(@(ScreenHeight));
            }
            make.height.equalTo(@(ScreenWidth));
            make.center.equalTo([UIApplication sharedApplication].keyWindow);
        }];
        [self.superview setNeedsLayout];
    } else {
        [_fullScreenBlackView removeFromSuperview];
        [self addPlayerToFatherView:self.fatherView];
    }
}

- (void)_switchToLayoutStyle:(SuperPlayerLayoutStyle)style {
    // 获取到当前状态条的方向

//    UIInterfaceOrientation currentOrientation = [UIDevice currentDevice].orientation;
    // 判断如果当前方向和要旋转的方向一致,那么不做任何操作
//    if (currentOrientation == orientation) { return; }
    
    // 根据要旋转的方向,使用Masonry重新修改限制
    if (style == SuperPlayerLayoutStyleFullScreen) {//
        // 这个地方加判断是为了从全屏的一侧,直接到全屏的另一侧不用修改限制,否则会出错;
        if (_layoutStyle != SuperPlayerLayoutStyleFullScreen)  { //UIInterfaceOrientationIsPortrait(currentOrientation)) {
            [self removeFromSuperview];
            CGFloat height = self.isVFullScreen ? ScreenHeight : ScreenWidth;
            CGFloat width = self.isVFullScreen ? ScreenWidth : ScreenHeight;
            
            [[UIApplication sharedApplication].keyWindow addSubview:_fullScreenBlackView];
            [_fullScreenBlackView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@(width));
                make.height.equalTo(@(height));
                make.center.equalTo([UIApplication sharedApplication].keyWindow);
            }];

            [[UIApplication sharedApplication].keyWindow addSubview:self];
            [self mas_remakeConstraints:^(MASConstraintMaker *make) {
                if (IsIPhoneX) {
                    if(self.isVFullScreen){
                        make.width.equalTo(@(width));
                        make.height.equalTo(@(height - self.mm_safeAreaTopGap - self.mm_safeAreaBottomGap));
                    }else{
                        make.width.equalTo(@(width - self.mm_safeAreaTopGap * 2));
                        make.height.equalTo(@(height));
                    }
                    
                } else {
                    make.width.equalTo(@(width));
                    make.height.equalTo(@(height));
                }

                make.center.equalTo([UIApplication sharedApplication].keyWindow);
            }];
            
        }
    } else {
        [_fullScreenBlackView removeFromSuperview];
    }
    self.controlView.compact = style == SuperPlayerLayoutStyleCompact;

    [[UIApplication sharedApplication].keyWindow  layoutIfNeeded];
    if (self.playDidEnd) {
        self.repeatBackBtn.hidden = YES;
    }

    // iOS6.0之后,设置状态条的方法能使用的前提是shouldAutorotate为NO,也就是说这个视图控制器内,旋转要关掉;
    // 也就是说在实现这个方法的时候-(BOOL)shouldAutorotate返回值要为NO
    /*
    [[UIApplication sharedApplication] setStatusBarOrientation:orientation animated:NO];
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
    // 更改了状态条的方向,但是设备方向UIInterfaceOrientation还是正方向的,这就要设置给你播放视频的视图的方向设置旋转
    // 给你的播放视频的view视图设置旋转
    self.transform = CGAffineTransformIdentity;
    self.transform = [self getTransformRotationAngleOfOrientation:[UIDevice currentDevice].orientation];
    
    _fullScreenContainerView.transform = self.transform;
    // 开始旋转
    [UIView commitAnimations];
    
    [self.fatherView.mm_viewController setNeedsStatusBarAppearanceUpdate];
    _layoutStyle = style;
     */
}

- (void)_adjustTransform:(UIDeviceOrientation)orientation {

    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];

    self.transform = [self getTransformRotationAngleOfOrientation:orientation];
    _fullScreenBlackView.transform = self.transform;
    [UIView commitAnimations];
}

/**
 * 获取变换的旋转角度
 *
 * @return 变换矩阵
 */
- (CGAffineTransform)getTransformRotationAngleOfOrientation:(UIDeviceOrientation)orientation {
    // 状态条的方向已经设置过,所以这个就是你想要旋转的方向
    UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
    if (interfaceOrientation == (UIInterfaceOrientation)orientation) {
        return CGAffineTransformIdentity;
    }
    if (interfaceOrientation == UIInterfaceOrientationPortrait && self.isVFullScreen) {
        return CGAffineTransformIdentity;
    }
    // 根据要进行旋转的方向来计算旋转的角度
    if (orientation == UIInterfaceOrientationPortrait) {
        return CGAffineTransformIdentity;
    } else if (orientation == UIInterfaceOrientationLandscapeLeft){
        return CGAffineTransformMakeRotation(-M_PI_2);
    } else if(orientation == UIInterfaceOrientationLandscapeRight){
        return CGAffineTransformMakeRotation(M_PI_2);
    }
    return CGAffineTransformIdentity;
}

#pragma mark 屏幕转屏相关

/**
 *  屏幕转屏
 *
 *  @param orientation 屏幕方向
 */
- (void)interfaceOrientation:(UIInterfaceOrientation)orientation {
    if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft) {
        // 设置横屏
        [self setOrientationLandscapeConstraint:orientation];
    } else if (orientation == UIInterfaceOrientationPortrait) {
        // 设置竖屏
        [self setOrientationPortraitConstraint];
    }
}
/**
 *  设置横屏的约束
 */
- (void)setOrientationLandscapeConstraint:(UIInterfaceOrientation)orientation {
    _isFullScreen = YES;
    //    [self _switchToLayoutStyle:orientation];
}

/**
 *  设置竖屏的约束
 */
- (void)setOrientationPortraitConstraint {
    [self addPlayerToFatherView:self.fatherView];
    _isFullScreen = NO;
//    [self _switchToLayoutStyle:UIInterfaceOrientationPortrait];
}

- (SuperPlayerLayoutStyle)defaultStyleForDeviceOrientation:(UIDeviceOrientation)orientation {
    if (UIDeviceOrientationIsPortrait(orientation)) {
        return SuperPlayerLayoutStyleCompact;
    } else {
        return SuperPlayerLayoutStyleFullScreen;
    }
}

#pragma mark - Action

/**
 *   轻拍方法
 *
 *  @param gesture UITapGestureRecognizer
 */
- (void)singleTapAction:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        //暂停状态和 结束状态不执行隐藏控制器
        if (self.playDidEnd) {
            return;
        }
        if (SuperPlayerWindowShared.isShowing)
            return;
        
        if (self.controlView.hidden) {
            [self.controlView fadeShow];
            [self updateSubtitleViewPoint:YES];
            if (!self.disableAutoHideControl) {
                if (!self.controlView.isShowSecondView && self.state != StatePause) {
                    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(controlViewFadeOut) object:nil];
                    [self performSelector:@selector(controlViewFadeOut) withObject:nil afterDelay:2.5];
                }
            }
            
        } else {
            [self.controlView fadeOut:0.2];
            [self updateSubtitleViewPoint:NO];
        }
        if ([self.delegate respondsToSelector:@selector(superPlayerSingleTap:)]) {
            [self.delegate superPlayerSingleTap:self];
        }
    }
}
- (void)updateSubtitleViewPoint:(BOOL)isHiden{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if(isHiden){
            [self.subtitlesView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.bottom.mas_equalTo(self.tagView.mas_top).offset(-10);
                make.centerX.mas_equalTo(self);
                make.width.mas_lessThanOrEqualTo(300);
            }];
        }else{
            [self.subtitlesView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.bottom.mas_equalTo(self).offset(-100);
                make.centerX.mas_equalTo(self);
                make.width.mas_lessThanOrEqualTo(300);
            }];
        }
    });
}
- (void)controlViewFadeOut {
    [self.controlView fadeOut:0.35];
    [self updateSubtitleViewPoint:NO];
}

/**
 *  双击播放/暂停
 *
 *  @param gesture UITapGestureRecognizer
 */
- (void)doubleTapAction:(UIGestureRecognizer *)gesture {
    if (self.playDidEnd) { return;  }
    // 显示控制层
    [self.controlView fadeShow];
    [self updateSubtitleViewPoint:YES];
 
    if (self.playDidEnd) {
        [self.vodPlayer stopPlay];
        [self setVodPlayConfig];
        [self restart];
    } else {
        if (self.isPauseByUser) {
            _playerModel.action == PLAY_ACTION_MANUAL_PLAY ? [self controllViewPlayClick] : [self resume];
        } else {
            [self pause];
        }
    }
}

/** 全屏 */
- (void)setFullScreen:(BOOL)fullScreen {

    if (_isFullScreen != fullScreen) {
        [self _adjustTransform:[self _orientationForFullScreen:fullScreen]];
        [self _switchToFullScreen:fullScreen];
        [self _switchToLayoutStyle:fullScreen ? SuperPlayerLayoutStyleFullScreen : SuperPlayerLayoutStyleCompact];
    }
    _isFullScreen = fullScreen;
    /*
    self.controlView.compact = !_isFullScreen;
    if (fullScreen) {
        UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
        if (orientation == UIDeviceOrientationLandscapeRight) {
            [self interfaceOrientation:UIInterfaceOrientationLandscapeLeft];
        } else {
            [self interfaceOrientation:UIInterfaceOrientationLandscapeRight];
        }
    } else {
        [self setOrientationPortraitConstraint];
        [self interfaceOrientation:UIInterfaceOrientationPortrait];
    }
     */
}


/**
 *  播放完了
 *
 */
- (void)moviePlayDidEnd {
    self.state = StateStopped;
    self.playDidEnd = YES;
    // 播放结束隐藏
    if (SuperPlayerWindowShared.isShowing) {
        [SuperPlayerWindowShared hide];
        [self resetPlayer];
    }
    [self.controlView setPlayState:NO];
    [self.controlView fadeOut:0.2];
    [self fastViewUnavaliable];
    [self.netWatcher stopWatch];
    self.repeatBtn.hidden = NO;
    if (_isFullScreen)  {
        self.repeatBackBtn.hidden = NO;
    }
    if ([self.delegate respondsToSelector:@selector(superPlayerDidEnd:)]) {
        [self.delegate superPlayerDidEnd:self];
    }
}

#pragma mark - UIKit Notifications

/**
 *  应用退到后台
 */
- (void)appDidEnterBackground:(NSNotification *)notify {
    [self fastViewUnavaliable];
    NSLog(@"appDidEnterBackground");
    self.didEnterBackground = YES;
    if (self.isLive || !self.autoPauseInBackground) {
        return;
    }
    
    if (!self.isPauseByUser && (self.state != StateStopped && self.state != StateFailed)) {
        [_vodPlayer pause];
        self.state = StatePause;
    }
}

/**
 *  应用进入前台
 */
- (void)appDidEnterPlayground:(NSNotification *)notify {
    [self fastViewUnavaliable];
    NSLog(@"appDidEnterPlayground");
    self.didEnterBackground = NO;
    if (self.isLive || !self.autoPauseInBackground) {
        return;
    }
    
    if (!self.isPauseByUser && (self.state != StateStopped && self.state != StateFailed)) {
        self.state = StatePlaying;
        [_vodPlayer resume];
        CGFloat value        = _vodPlayer.currentPlaybackTime / _vodPlayer.duration;
        CGFloat playable     = _vodPlayer.playableDuration / _vodPlayer.duration;
        self.controlView.isDragging = NO;
        [self.controlView setProgressTime:self.playCurrentTime totalTime:_vodPlayer.duration progressValue:value playableValue:playable];
        [_vodPlayer seek:self.playCurrentTime];
    } else if (self.state != StateStopped) {
        self.repeatBtn.hidden = YES;
    }
}

// 状态条变化通知（在前台播放才去处理）
- (void)onStatusBarOrientationChange {
    [self onDeviceOrientationChange];
    return;
    if (!self.didEnterBackground) {
        UIInterfaceOrientation orientation = (UIInterfaceOrientation)[UIDevice currentDevice].orientation;
        SuperPlayerLayoutStyle style = [self defaultStyleForDeviceOrientation:orientation];
//        [[UIApplication sharedApplication] setStatusBarOrientation:orientation animated:NO];
        if ([UIApplication sharedApplication].statusBarOrientation != orientation) {
            [self _adjustTransform:(UIInterfaceOrientation)[UIDevice currentDevice].orientation];
        }
        [self _switchToFullScreen:style == SuperPlayerLayoutStyleFullScreen];
        [self _switchToLayoutStyle:style];
 /*       // 获取到当前状态条的方向
        UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
        if (currentOrientation == UIInterfaceOrientationPortrait) {
            [self setOrientationPortraitConstraint];
        } else {
            [self _switchToLayoutStyle:style];

            if (currentOrientation == UIInterfaceOrientationLandscapeRight) {
                [self _switchToLayoutStyle:style];
            } else if (currentOrientation == UIDeviceOrientationLandscapeLeft){
                [self _switchToLayoutStyle:UIInterfaceOrientationLandscapeLeft];
            }
        }
   */
    }
}

/**
 *  屏幕方向发生变化会调用这里
 */
- (void)onDeviceOrientationChange {
    if (!self.isLoaded) { return; }
    if (self.isLockScreen) { return; }
    if (self.didEnterBackground) { return; };
    if (SuperPlayerWindowShared.isShowing) { return; }
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    if (orientation == UIDeviceOrientationFaceUp) {
        return;
    }
    SuperPlayerLayoutStyle style = [self defaultStyleForDeviceOrientation:[UIDevice currentDevice].orientation];

    BOOL shouldFullScreen = UIDeviceOrientationIsLandscape(orientation);
    [self _switchToFullScreen:shouldFullScreen];
    [self _adjustTransform:[self _orientationForFullScreen:shouldFullScreen]];
    [self _switchToLayoutStyle:style];
}

#pragma mark -
- (void)seekToTime:(NSInteger)dragedSeconds {
    if (!self.isLoaded || self.state == StateStopped) {
        return;
    }
    if (self.isLive) {
        [DataReport report:@"timeshift" param:nil];
    } else {
        if (!self.disableAutoHideControl) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(controlViewFadeOut) object:nil];
            [self performSelector:@selector(controlViewFadeOut) withObject:nil afterDelay:2.5];
        }
        if (!_vodPlayer) {
            [self setVodPlayConfig];
            [self restart];
        } else {
            [self.vodPlayer resume];
            [self.spinner startAnimating];
            [self.vodPlayer seek:dragedSeconds];
            [self.controlView setPlayState:YES];
        }
    }
}

#pragma mark - UIPanGestureRecognizer手势方法
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        if (self.disableTapGesture) {
            return NO;
        }
        return YES;
    }

    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        if (!self.isLoaded) { return NO; }
        if (self.isLockScreen) { return NO; }
        if (SuperPlayerWindowShared.isShowing) { return NO; }
        
        if (self.disableGesture) {
            if (!self.isFullScreen) {
                return NO;
            }
        }
        return YES;
    }
    
    return NO;
}
/**
 *  pan手势事件
 *
 *  @param pan UIPanGestureRecognizer
 */
- (void)panDirection:(UIPanGestureRecognizer *)pan {

    //根据在view上Pan的位置，确定是调音量还是亮度
    CGPoint locationPoint = [pan locationInView:self];
    
    // 我们要响应水平移动和垂直移动
    // 根据上次和本次移动的位置，算出一个速率的point
    CGPoint veloctyPoint = [pan velocityInView:self];
    
    if (self.state == StateStopped)
        return;
    
    // 判断是垂直移动还是水平移动
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{ // 开始移动
            // 使用绝对值来判断移动的方向
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            if (x > y) { // 水平移动
                // 取消隐藏
                self.panDirection = PanDirectionHorizontalMoved;
                self.sumTime      = [self playCurrentTime];
            }
            else if (x < y){ // 垂直移动
                self.panDirection = PanDirectionVerticalMoved;
                // 开始滑动的时候,状态改为正在控制音量
                if (locationPoint.x > self.bounds.size.width / 2) {
                    self.isVolume = YES;
                }else { // 状态改为显示亮度调节
                    self.isVolume = NO;
                }
            }
            self.isDragging = YES;
            [self.controlView fadeOut:0.2];
            [self updateSubtitleViewPoint:NO];

            break;
        }
        case UIGestureRecognizerStateChanged:{ // 正在移动
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    [self horizontalMoved:veloctyPoint.x]; // 水平移动的方法只要x方向的值
                    break;
                }
                case PanDirectionVerticalMoved:{
                    [self verticalMoved:veloctyPoint.y]; // 垂直移动方法只要y方向的值
                    break;
                }
                default:
                    break;
            }
            self.isDragging = YES;
            break;
        }
        case UIGestureRecognizerStateEnded:{ // 移动停止
            // 移动结束也需要判断垂直或者平移
            // 比如水平移动结束时，要快进到指定位置，如果这里没有判断，当我们调节音量完之后，会出现屏幕跳动的bug
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    self.isPauseByUser = NO;
                    [self seekToTime:self.sumTime];
                    // 把sumTime滞空，不然会越加越多
                    self.sumTime = 0;
                    break;
                }
                case PanDirectionVerticalMoved:{
                    // 垂直移动结束后，把状态改为不再控制音量
                    self.isVolume = NO;
                    break;
                }
                default:
                    break;
            }
            [self fastViewUnavaliable];
            self.isDragging = NO;
            break;
        }
        case UIGestureRecognizerStateCancelled: {
            self.sumTime = 0;
            self.isVolume = NO;
            [self fastViewUnavaliable];
            self.isDragging = NO;
        }
        default:
            break;
    }
}

/**
 *  pan垂直移动的方法
 *
 *  @param value void
 */
- (void)verticalMoved:(CGFloat)value {
   
    self.isVolume ? ([[self class] volumeViewSlider].value -= value / 10000) : ([UIScreen mainScreen].brightness -= value / 10000);

    if (self.isVolume) {
        [self fastViewImageAvaliable:SuperPlayerImage(@"sound_max") progress:[[self class] volumeViewSlider].value];
    } else {
        [self fastViewImageAvaliable:SuperPlayerImage(@"light_max") progress:[UIScreen mainScreen].brightness];
    }
}

/**
 *  pan水平移动的方法
 *
 *  @param value void
 */
- (void)horizontalMoved:(CGFloat)value {
    // 每次滑动需要叠加时间
    CGFloat totalMovieDuration = [self playDuration];
    self.sumTime += value / 10000 * totalMovieDuration;
    
    if (self.sumTime > totalMovieDuration) { self.sumTime = totalMovieDuration;}
    if (self.sumTime < 0) { self.sumTime = 0; }
    
    [self fastViewProgressAvaliable:self.sumTime];
}

- (void)volumeChanged:(NSNotification *)notification
{
    if (self.isDragging)
        return; // 正在拖动，不响应音量事件
    
    if (![[[notification userInfo] objectForKey:@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"] isEqualToString:@"ExplicitVolumeChange"]) {
        return;
    }
    float volume = [[[notification userInfo] objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
    [self fastViewImageAvaliable:SuperPlayerImage(@"sound_max") progress:volume];
    [self.fastView fadeOut:1];
}

- (SuperPlayerFastView *)fastView
{
    if (_fastView == nil) {
        if (self.hiddenFastView) {
            return nil;
        }
        _fastView = [[SuperPlayerFastView alloc] init];
        [self addSubview:_fastView];
        [_fastView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(UIEdgeInsetsZero);
        }];
    }
    return _fastView;
}

- (void)fastViewImageAvaliable:(UIImage *)image progress:(CGFloat)draggedValue {
    if (self.controlView.isShowSecondView)
        return;
    [self.fastView showImg:image withProgress:draggedValue];
    [self.fastView fadeShow];
}

- (void)fastViewProgressAvaliable:(NSInteger)draggedTime {
    NSInteger totalTime = 0;
    if (_playerModel.duration > 0) {
        totalTime = _playerModel.duration;
    } else {
        totalTime = [self playDuration];
    }
    NSString *currentTimeStr = [StrUtils timeFormat:draggedTime];
    NSString *totalTimeStr   = [StrUtils timeFormat:totalTime];
    NSString *timeStr        = [NSString stringWithFormat:@"%@ / %@", currentTimeStr, totalTimeStr];
    if (self.isLive) {
        timeStr = [NSString stringWithFormat:@"%@", currentTimeStr];
    }

    UIImage *thumbnail;
    if (self.isFullScreen) {
        thumbnail = [self.imageSprite getThumbnail:draggedTime];
    }
    if (thumbnail) {
        self.fastView.videoRatio = self.videoRatio;
        [self.fastView showThumbnail:thumbnail withText:timeStr];
    } else {
        CGFloat sliderValue = 1;
        if (totalTime > 0) {
            sliderValue = (CGFloat)draggedTime/totalTime;
        }
        if (self.isLive && totalTime > MAX_SHIFT_TIME) {
            CGFloat base = totalTime - MAX_SHIFT_TIME;
            if (self.sumTime < base)
                self.sumTime = base;
            sliderValue = (self.sumTime - base) / MAX_SHIFT_TIME;
            NSLog(@"%f",sliderValue);
        }
        [self.fastView showText:timeStr withText:sliderValue];
    }
    [self.fastView fadeShow];
}

- (void)fastViewUnavaliable
{
    [self.fastView fadeOut:0.1];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    

    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        if (self.playDidEnd){
            return NO;
        }
    }

    if ([touch.view isKindOfClass:[UISlider class]] || [touch.view.superview isKindOfClass:[UISlider class]]) {
        return NO;
    }
    
    if (SuperPlayerWindowShared.isShowing)
        return NO;

    return YES;
}

#pragma mark - Setter


/**
 *  设置播放的状态
 *
 *  @param state SuperPlayerState
 */
- (void)setState:(SuperPlayerState)state {
        
    _state = state;
    // 控制菊花显示、隐藏
    if (state == StateBuffering) {
        if ([self.delegate respondsToSelector:@selector(superPlayerLoading:)]) {
            [self.delegate superPlayerLoading:self];
        }
        [self.spinner startAnimating];
    } else {
        if ([self.delegate respondsToSelector:@selector(superPlayerLoadingEnd:)]) {
            [self.delegate superPlayerLoadingEnd:self];
        }
        if (!self.autoAdjustRenderMode) {
            [self.spinner stopAnimating];
        }
    }
    if (state == StatePlaying) {
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                      object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(volumeChanged:)
                                                     name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                   object:nil];
        
        if (!self.autoAdjustRenderMode) {
            if (self.coverImageView.alpha == 1) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.coverImageView.alpha = 0;
                }];
            }
        }
    } else if (state == StateFailed) {
        
    } else if (state == StateStopped) {
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                      object:nil];
        
        self.coverImageView.alpha = 1;
        
    } else if (state == StatePause) {

    }
}

- (void)setControlView:(SuperPlayerControlView *)controlView {
    if (_controlView == controlView) {
        return;
    }
    [_controlView removeFromSuperview];

    controlView.delegate = self;
    [self addSubview:controlView];
    [controlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(UIEdgeInsetsZero);
    }];
    [controlView playerBegin:self.playerModel isLive:self.isLive isTimeShifting:self.isShiftPlayback isAutoPlay:self.autoPlay];
    [self resetControlViewWithLive:self.isLive shiftPlayback:self.isShiftPlayback isPlaying:self.state == StatePlaying ? YES : NO]; 
    [controlView setTitle:_controlView.title];
    [controlView setPointArray:_controlView.pointArray];
    
    _controlView = controlView;
}

- (SuperPlayerControlView *)controlView
{
    if (_controlView == nil) {
        self.controlView = [[SPWeiboControlView alloc] initWithFrame:CGRectZero];
    }
    return _controlView;
}

- (void)setDragging:(BOOL)dragging
{
    _isDragging = dragging;
    if (dragging) {
        [[NSNotificationCenter defaultCenter]
         removeObserver:self name:@"AVSystemController_SystemVolumeDidChangeNotification"
         object:nil];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
             addObserver:self
             selector:@selector(volumeChanged:)
             name:@"AVSystemController_SystemVolumeDidChangeNotification"
             object:nil];
        });
    }
}

- (void)setLoop:(BOOL)loop
{
    _loop = loop;
    if (self.vodPlayer) {
        self.vodPlayer.loop = loop;
    }
}

#pragma mark - Getter

- (CGFloat)playDuration {
    if (self.isLive) {
        return self.maxLiveProgressTime;
    }
    
    return self.vodPlayer.duration;
}

- (CGFloat)playCurrentTime {
    if (self.isLive) {
        if (self.isShiftPlayback) {
            return self.liveProgressTime;
        }
        return self.maxLiveProgressTime;
    }
    
    return _playCurrentTime;
}

+ (UISlider *)volumeViewSlider {
    return _volumeSlider;
}
#pragma mark - SuperPlayerControlViewDelegate

- (void)controlViewPlay:(SuperPlayerControlView *)controlView {
    ///播放中断，重新播放的时候隐藏middlemsg
    if (self.middleBlackBtn.hidden == NO) {
        self.middleBlackBtn.hidden = YES;
    }
    if (self.playDidEnd) {
        [self.vodPlayer stopPlay];
        [self setVodPlayConfig];
        [self restart];
    } else {
        [self controllViewPlayClick];
    }
}

- (void)controlViewPause:(SuperPlayerControlView *)controlView
{
    [self pause];
    if (self.state == StatePlaying) { self.state = StatePause;}
}

- (void)controlViewBack:(SuperPlayerControlView *)controlView {
    [self controlViewBackAction:controlView];
}

- (void)controlViewBackAction:(id)sender {
    if (self.isFullScreen) {
        self.isFullScreen = NO;
        return;
    }
    if ([self.delegate respondsToSelector:@selector(superPlayerBackAction:)]) {
        [self.delegate superPlayerBackAction:self];
    }
}

- (void)controlViewChangeScreen:(SuperPlayerControlView *)controlView withFullScreen:(BOOL)isFullScreen {
    self.isFullScreen = isFullScreen;
}

- (void)controlViewDidChangeScreen:(UIView *)controlView
{
    if ([self.delegate respondsToSelector:@selector(superPlayerFullScreenChanged:)]) {
        [self.delegate superPlayerFullScreenChanged:self];
    }
}

- (void)controlViewLockScreen:(SuperPlayerControlView *)controlView withLock:(BOOL)isLock {
    self.isLockScreen = isLock;
}

- (void)controlViewSwitch:(SuperPlayerControlView *)controlView withDefinition:(NSString *)definition {
    
    if ([self.playerModel.playingDefinition isEqualToString:definition]) return;
    self.playerModel.playingDefinition = definition;
    
    if (self.isLive) {
        [self.livePlayer switchStream:_currentVideoUrl];
        [self showMiddleBtnMsg:[NSString stringWithFormat:@"正在切换到%@...", definition] withAction:ActionNone];
    } else {
        self.controlView.hidden = YES;
        if (!self.playDidEnd) {
            if ([self.vodPlayer supportedBitrates].count > 1) {
                [self.vodPlayer setBitrateIndex:self.playerModel.playingDefinitionIndex];
            } else {
                CGFloat startTime = [self.vodPlayer currentPlaybackTime];
                [self.vodPlayer stopPlay];
                self.state = StateStopped;
                [self.vodPlayer setStartTime:startTime];
                [self.vodPlayer startVodPlay:_currentVideoUrl];
                if (_playerModel.action == PLAY_ACTION_PRELOAD) {
                    [self resume];
                }
            }
        }
    }
        
    [self.vodPlayer setRate:self.playerConfig.playRate];
    [self.vodPlayer setMirror:self.playerConfig.mirror];
    [self.vodPlayer setMute:self.playerConfig.mute];
    [self.vodPlayer setRenderMode:self.playerConfig.renderMode];
}

- (void)controlViewConfigUpdate:(SuperPlayerControlView *)controlView withReload:(BOOL)reload {
    if (self.state == StateStopped && !self.isLive) {
        return;
    }
    
    if (self.isLive) {
        [self.livePlayer setMute:self.playerConfig.mute];
        [self.livePlayer setRenderMode:self.playerConfig.renderMode];
    } else {
        [self.vodPlayer setRate:self.playerConfig.playRate];
        [self.vodPlayer setMirror:self.playerConfig.mirror];
        [self.vodPlayer setMute:self.playerConfig.mute];
        [self.vodPlayer setRenderMode:self.playerConfig.renderMode];
    }
    if (reload) {
        if (!self.isLive) self.startTime = [self.vodPlayer currentPlaybackTime];
        self.isShiftPlayback = NO;
        [self configTXPlayer];
        self.state = StateStopped;
        if (_playerModel.action == PLAY_ACTION_PRELOAD) {
            [self resume];
        }
        
        if (self.state != StatePlaying && _playerModel.action == PLAY_ACTION_MANUAL_PLAY) {
            [self controllViewPlayClick];
        }
    }
}

- (void)controlViewReload:(UIView *)controlView {
    if (self.isLive) {
        self.isShiftPlayback = NO;
        self.isLoaded        = NO;
        [self resetControlViewWithLive:self.isLive shiftPlayback:self.isShiftPlayback isPlaying:YES];
    } else {
        self.startTime = [self.vodPlayer currentPlaybackTime];
        [self configTXPlayer];
    }
}

- (void)controlViewSnapshot:(SuperPlayerControlView *)controlView {
    
    void (^block)(UIImage *img) = ^(UIImage *img) {
        [self.fastView showSnapshot:img];
        
        if ([self.fastView.snapshotView gestureRecognizers].count == 0) {
            UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPhotos)];
            singleTap.numberOfTapsRequired = 1;
            [self.fastView.snapshotView setUserInteractionEnabled:YES];
            [self.fastView.snapshotView addGestureRecognizer:singleTap];
        }
        [self.fastView fadeShow];
        [self.fastView fadeOut:2];
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
    };
    
    if (_isLive) {
        [_livePlayer snapshot:block];
    } else {
        [_vodPlayer snapshot:block];
    }
}

-(void)openPhotos {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"photos-redirect://"]];
}

- (CGFloat)sliderPosToTime:(CGFloat)pos {
    // 视频总时间长度
    CGFloat totalTime = 0;
    if (_playerModel.duration > 0) {
        totalTime = _playerModel.duration;
    } else {
        totalTime = [self playDuration];
    }

    //计算出拖动的当前秒数
    CGFloat dragedSeconds = floorf(totalTime * pos);
    if (self.isLive && totalTime > MAX_SHIFT_TIME) {
        CGFloat base  = totalTime - MAX_SHIFT_TIME;
        dragedSeconds = floor(MAX_SHIFT_TIME * pos) + base;
    }
    return dragedSeconds;
}

- (void)controlViewSeek:(SuperPlayerControlView *)controlView where:(CGFloat)pos {
    CGFloat dragedSeconds = [self sliderPosToTime:pos];
    if (_playerModel.action == PLAY_ACTION_PRELOAD) {
        self->_isPrepare = NO;
        self.isPauseByUser = NO;
        [self.controlView setPlayState:YES];
        [self.vodPlayer resume];
        [self.vodPlayer seek:dragedSeconds];
    } else {
        if (self.state == StateStopped) {
            [self.vodPlayer setStartTime:dragedSeconds];
            [self.vodPlayer startVodPlay:_currentVideoUrl];
        } else {
            [self seekToTime:dragedSeconds];
        }
        
        [self.controlView setPlayState:YES];
        self.repeatBtn.hidden = YES;

    }
    [self fastViewUnavaliable];
}

- (void)controlViewPreview:(SuperPlayerControlView *)controlView where:(CGFloat)pos {
    CGFloat dragedSeconds = [self sliderPosToTime:pos];
    if ([self playDuration] > 0) {  // 当总时长 > 0时候才能拖动slider
        [self fastViewProgressAvaliable:dragedSeconds];
    }
}


- (void)controlViewSwitch:(UIView *)controlView withTrackInfo:(TXTrackInfo *)info preTrackInfo:(TXTrackInfo *)preInfo {
    if (info.trackIndex == -1) {
        [self.vodPlayer deselectTrack:preInfo.trackIndex];
    } else {
        if (preInfo.trackIndex != -1) {
            [self.vodPlayer deselectTrack:preInfo.trackIndex];
            [self.vodPlayer selectTrack:info.trackIndex];
        }
    }
    
    [self.controlView fadeOut:1];
}

- (void)controlViewSwitch:(UIView *)controlView withSubtitlesInfo:(TXTrackInfo *)info preSubtitlesInfo:(TXTrackInfo *)preInfo {
    if (info.trackIndex == -1) {
        [self.vodPlayer deselectTrack:preInfo.trackIndex];
    } else {
        if (preInfo.trackIndex != -1) {
            [self.vodPlayer deselectTrack:preInfo.trackIndex];
        }
        [self.vodPlayer selectTrack:info.trackIndex];
    }
    
    [self.controlView fadeOut:1];
}


#pragma clang diagnostic pop
#pragma mark - 点播回调

- (void)_removeOldPlayer {
    for (UIView *w in [self subviews]) {
        if ([w isKindOfClass:NSClassFromString(@"TXCRenderView")]) [w removeFromSuperview];
        if ([w isKindOfClass:NSClassFromString(@"TXIJKSDLGLView")]) [w removeFromSuperview];
        if ([w isKindOfClass:NSClassFromString(@"TXCAVPlayerView")]) [w removeFromSuperview];
        if ([w isKindOfClass:NSClassFromString(@"TXCThumbPlayerView")]) [w removeFromSuperview];
    }
}

- (void)onPlayEvent:(TXVodPlayer *)player event:(int)EvtID withParam:(NSDictionary *)param {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (EvtID != PLAY_EVT_PLAY_PROGRESS) {
            NSString *desc = [param description];
            NSLog(@"%@", [NSString stringWithCString:[desc cStringUsingEncoding:NSUTF8StringEncoding] encoding:NSNonLossyASCIIStringEncoding]);
        }
        
        float duration = self->_playerModel.duration > 0 ? self->_playerModel.duration : player.duration;
        
        if (EvtID == PLAY_EVT_RCV_FIRST_I_FRAME) {
            self.state = StateFirstFrame;
        }
        
        if (EvtID == EVT_VIDEO_PLAY_BEGIN) {
            self.isLoaded = YES;
            self.state = StatePlaying;
            [self.controlView setPlayState:YES];
            self.repeatBtn.hidden = YES;
            self.playDidEnd = NO;
            //1.开始播放后自动隐藏 2.如果视频自动播放才需要隐藏
            if (!self.disableAutoHideControl && self.autoPlay) {
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(controlViewFadeOut) object:nil];
                [self performSelector:@selector(controlViewFadeOut) withObject:nil afterDelay:2.5];
            }
            // 不使用vodPlayer.autoPlay的原因是暂停的时候会黑屏，影响体验
            [self prepareAutoplay];
        }
        if (EvtID == PLAY_EVT_VOD_PLAY_PREPARED) {
            [self updateBitrates:player.supportedBitrates];
            [self detailPrepareState];
        }
        if (EvtID == PLAY_EVT_PLAY_PROGRESS) {
            [self detailProgress];
            self.playCurrentTime = player.currentPlaybackTime;
            CGFloat totalTime    = duration;
            CGFloat value        = player.currentPlaybackTime / duration;
            CGFloat playable     = player.playableDuration / duration;
            
            //由于设置开始时间后，state先StatePlaying后StateFirstFrame，故添加StateFirstFrame
            if (self.state == StatePlaying || self.state == StateFirstFrame) {
                [self updateSubtitleForTime:self.playCurrentTime];
                [self.controlView setProgressTime:self.playCurrentTime totalTime:totalTime progressValue:value playableValue:playable];
            }
            
        } else if (EvtID == PLAY_EVT_PLAY_END) {
            [self.controlView setProgressTime:[self playDuration] totalTime:[self playDuration] progressValue:player.duration / duration playableValue:player.duration / duration];
            [self moviePlayDidEnd];
        } else if (EvtID == PLAY_ERR_NET_DISCONNECT || EvtID == PLAY_ERR_FILE_NOT_FOUND
                   || EvtID == PLAY_ERR_HLS_KEY || EvtID == VOD_PLAY_ERR_DEMUXER_FAIL ||
                   EvtID == PLAY_ERR_GET_PLAYINFO_FAIL) {
            self.playDidEnd = YES;
            [self.controlView setPlayState:NO];
            [self detailPlayerEvent:player event:EvtID param:param];
            
        } else if (EvtID == PLAY_EVT_PLAY_LOADING) {
            // 当缓冲是空的时候
            self.state = StateBuffering;

        } else if (EvtID == PLAY_EVT_VOD_LOADING_END) {
            if (self.state == StateBuffering) {
                self.state = StatePlaying;
            }
            [self.spinner stopAnimating];
        } else if (EvtID == PLAY_EVT_CHANGE_RESOLUTION) {
            if (player.height != 0) {
                self.videoRatio = (GLfloat)player.width / player.height;
            }
        } else if (EvtID == PLAY_EVT_GET_PLAYINFO_SUCC) {
            self->_currentVideoUrl = [param objectForKey:VOD_PLAY_EVENT_PLAY_URL];
        }
    });
}

- (void)changeSubtitlesData:(NSMutableArray *)subtitles {
    self.subtitlesArray = subtitles;
}
-(void) onNetStatus:(TXVodPlayer *)player withParam:(NSDictionary*)param {
    
    CGFloat videoWidth = [[param objectForKey:NET_STATUS_VIDEO_WIDTH] floatValue];
    CGFloat videoHeight = [[param objectForKey:NET_STATUS_VIDEO_HEIGHT] floatValue];
    
    if (videoWidth == 0 || videoHeight == 0) {
        return;
    }
    
    if (videoHeight / videoWidth > 1){
        self.isVFullScreen = YES;
    }
    
    if (!self.autoAdjustRenderMode) {
        return;
    }
    [self.spinner stopAnimating];
    if (videoWidth > videoHeight) {
        if (self.playerConfig.renderMode == RENDER_MODE_FILL_SCREEN) {
            self.coverImageView.alpha = 1;
            self.playerConfig.renderMode = RENDER_MODE_FILL_EDGE;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self.vodPlayer setRenderMode:self.playerConfig.renderMode];
            [CATransaction commit];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.coverImageView.alpha = 0;
            });
        } else {
            if (self.coverImageView.alpha == 1) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.coverImageView.alpha = 0;
                }];
            }
        }
    } else {
        if (self.playerConfig.renderMode == RENDER_MODE_FILL_EDGE) {
            self.coverImageView.alpha = 1;
            self.playerConfig.renderMode = RENDER_MODE_FILL_SCREEN;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self.vodPlayer setRenderMode:self.playerConfig.renderMode];
            [CATransaction commit];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.coverImageView.alpha = 0;
            });
        } else {
            if (self.coverImageView.alpha == 1) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.coverImageView.alpha = 0;
                }];
            }
        }
    }
}

// 更新当前播放的视频信息，包括清晰度、码率等
- (void)updateBitrates:(NSArray<TXBitrateItem *> *)bitrates;
{
    // 播放离线视频，不更新清晰度，离线视频只有一个清晰度
    if ([_currentVideoUrl containsString:@"/var/mobile/Containers/Data/Application/"]) {
        return;
    }
    
    if (bitrates.count > 0) {
        NSArray *titles             = [TXBitrateItemHelper sortWithBitrate:bitrates];
        _playerModel.multiVideoURLs = titles;
        self.netWatcher.playerModel = _playerModel;
        NSInteger index = self.vodPlayer.bitrateIndex;
        if (_playerModel.playDefinitions.count > 0) {
            if (_playerModel.playDefinitions.count > index) {
                _playerModel.playingDefinition = _playerModel.playDefinitions[index < 0 ? 0 : index];
            } else {
                _playerModel.playingDefinition = _playerModel.playDefinitions.lastObject;
            }
        }
        [self resetControlViewWithLive:self.isLive shiftPlayback:self.isShiftPlayback isPlaying:self.state == StatePlaying ? YES : NO];
        if (_isFullScreen) {
            [self.controlView setOrientationLandscapeConstraint];
        }
    }
}

#pragma mark - 直播回调

- (void)onPlayEvent:(int)EvtID withParam:(NSDictionary *)param {
    NSDictionary *dict = param;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (EvtID != PLAY_EVT_PLAY_PROGRESS) {
            NSString *desc = [param description];
            NSLog(@"%@", [NSString stringWithCString:[desc cStringUsingEncoding:NSUTF8StringEncoding] encoding:NSNonLossyASCIIStringEncoding]);
        }
        
        if (EvtID == PLAY_EVT_RCV_FIRST_I_FRAME) {
            self.state = StateFirstFrame;
        }

        if (EvtID == PLAY_EVT_PLAY_BEGIN) {
            if (!self.isLoaded) {
                self.isLoaded = YES;
                self.state = StatePlaying;
                [self.controlView setPlayState:YES];
                if ([self.delegate respondsToSelector:@selector(superPlayerDidStart:)]) {
                    [self.delegate superPlayerDidStart:self];
                }
            }

            if (self.state == StateBuffering) self.state = StatePlaying;
            [self.netWatcher loadingEndEvent];
        } else if (EvtID == PLAY_EVT_PLAY_END) {
            [self moviePlayDidEnd];
        } else if (EvtID == PLAY_ERR_NET_DISCONNECT) {
            if (self.isShiftPlayback) {
                [self controlViewReload:self.controlView];
                [self showMiddleBtnMsg:kStrTimeShiftFailed withAction:ActionRetry];
                [self.middleBlackBtn fadeOut:2];
            } else {
                [self showMiddleBtnMsg:[SPBundleUtil spLocalizedStringForKey:kStrBadNetRetry]
                            withAction:ActionRetry];
                self.state = StateFailed;
            }
            if ([self.delegate respondsToSelector:@selector(superPlayerError:errCode:errMessage:)]) {
                [self.delegate superPlayerError:self errCode:EvtID errMessage:param[EVT_MSG]];
            }
        } else if (EvtID == PLAY_EVT_PLAY_LOADING){
            // 当缓冲是空的时候
            self.state = StateBuffering;
            if (!self.isShiftPlayback) {
                [self.netWatcher loadingEvent];
            }
        } else if (EvtID == PLAY_EVT_STREAM_SWITCH_SUCC) {
            [self showMiddleBtnMsg:[@"已切换为" stringByAppendingString:self.playerModel.playingDefinition] withAction:ActionNone];
            [self.middleBlackBtn fadeOut:1];
        } else if (EvtID == PLAY_ERR_STREAM_SWITCH_FAIL) {
            [self showMiddleBtnMsg:kStrHDSwitchFailed withAction:ActionRetry];
            self.state = StateFailed;
        } else if (EvtID == PLAY_EVT_PLAY_PROGRESS) {
            if (self.state == StateStopped)
                return;
            NSInteger progress = [dict[EVT_PLAY_PROGRESS] intValue];
            self.liveProgressTime = progress;
            self.maxLiveProgressTime = MAX(self.maxLiveProgressTime, self.liveProgressTime);
            
            if (self.isShiftPlayback) {
                CGFloat sv = 0;
                if (self.maxLiveProgressTime > MAX_SHIFT_TIME) {
                    CGFloat base = self.maxLiveProgressTime - MAX_SHIFT_TIME;
                    sv = (self.liveProgressTime - base) / MAX_SHIFT_TIME;
                } else {
                    sv = self.liveProgressTime / (self.maxLiveProgressTime + 1);
                }
                [self.controlView setProgressTime:self.liveProgressTime totalTime:-1 progressValue:sv playableValue:0];
            } else {
                [self.controlView setProgressTime:self.maxLiveProgressTime totalTime:-1 progressValue:1 playableValue:0];
            }
        }
    });
}

- (void)onNetStatus:(NSDictionary *)param {
    if (!self.autoAdjustRenderMode) {
        return;
    }
    CGFloat videoWidth = [[param objectForKey:NET_STATUS_VIDEO_WIDTH] floatValue];
    CGFloat videoHeight = [[param objectForKey:NET_STATUS_VIDEO_HEIGHT] floatValue];
    if (videoWidth == 0 || videoHeight == 0) {
        return;
    }
    [self.spinner stopAnimating];
    if (videoWidth > videoHeight) {
        if (self.playerConfig.renderMode == RENDER_MODE_FILL_SCREEN) {
            self.coverImageView.alpha = 1;
            self.playerConfig.renderMode = RENDER_MODE_FILL_EDGE;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self.livePlayer setRenderMode:self.playerConfig.renderMode];
            [CATransaction commit];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.coverImageView.alpha = 0;
            });
        } else {
            if (self.coverImageView.alpha == 1) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.coverImageView.alpha = 0;
                }];
            }
        }
    } else {
        if (self.playerConfig.renderMode == RENDER_MODE_FILL_EDGE) {
            self.coverImageView.alpha = 1;
            self.playerConfig.renderMode = RENDER_MODE_FILL_SCREEN;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self.livePlayer setRenderMode:self.playerConfig.renderMode];
            [CATransaction commit];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.coverImageView.alpha = 0;
            });
        } else {
            if (self.coverImageView.alpha == 1) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.coverImageView.alpha = 0;
                }];
            }
        }
    }
}

// 日志回调
-(void) onLog:(NSString*)log LogLevel:(int)level WhichModule:(NSString*)module
{
    NSLog(@"%@:%@", module, log);
}

- (int)livePlayerType {
    int playType = -1;
    NSString *videoURL = self.playerModel.playingDefinitionUrl;
    if ([videoURL hasPrefix:@"rtmp:"]) {
        playType = PLAY_TYPE_LIVE_RTMP;
    } else if (([videoURL hasPrefix:@"https:"] || [videoURL hasPrefix:@"http:"]) && ([videoURL rangeOfString:@".flv"].length > 0)) {
        playType = PLAY_TYPE_LIVE_FLV;
    }
    if (self.playAccURL) {
        return PLAY_TYPE_LIVE_RTMP_ACC;
    }
    return playType;
}

- (void)reportPlay {
    if (self.reportTime == nil)
        return;
    int usedtime = -[self.reportTime timeIntervalSinceNow];
    if (self.isLive) {
        [DataReport report:@"superlive" param:@{@"usedtime":@(usedtime)}];
    } else {
        [DataReport report:@"supervod" param:@{@"usedtime":@(usedtime), @"fileid":@(self.playerModel.videoId.fileId?1:0)}];
    }
    if (self.imageSprite) {
        [DataReport report:@"image_sprite" param:nil];
    }
    self.reportTime = nil;
}

#pragma mark - middle btn
- (UIButton *)middleBlackBtn
{
    if (_middleBlackBtn == nil) {
        _middleBlackBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_middleBlackBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _middleBlackBtn.titleLabel.font = [UIFont systemFontOfSize:14.0];
        _middleBlackBtn.backgroundColor = RGBA(0, 0, 0, 0.7);
        _middleBlackBtn.hidden = YES;
        [_middleBlackBtn addTarget:self action:@selector(middleBlackBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_middleBlackBtn];
        [_middleBlackBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.height.mas_equalTo(33);
        }];
    }
    return _middleBlackBtn;
}

- (void)showMiddleBtnMsg:(NSString *)msg withAction:(ButtonAction)action {
    if (self.hideMiddelBlackBtn) {
        return;
    }
    
    [self.middleBlackBtn setTitle:msg forState:UIControlStateNormal];
    self.middleBlackBtn.titleLabel.text = msg;
    self.middleBlackBtnAction = action;
    CGFloat width = self.middleBlackBtn.titleLabel.attributedText.size.width;
    [self.middleBlackBtn mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(width+10));
    }];
    [self.middleBlackBtn fadeShow];
}

- (void)middleBlackBtnClick:(UIButton *)btn
{
    switch (self.middleBlackBtnAction) {
        case ActionNone:
            break;
        case ActionContinueReplay: {
            if (!self.isLive) {
                self.startTime = self.playCurrentTime;
            }
            [self configTXPlayer];
        }
            break;
        case ActionRetry:
            [self reloadModel];
            break;
        case ActionSwitch:
            [self controlViewSwitch:self.controlView withDefinition:self.netWatcher.adviseDefinition];
            [self resetControlViewWithLive:self.isLive shiftPlayback:self.isShiftPlayback isPlaying:YES];
            break;
        case ActionIgnore:
            return;
        default:
            break;
    }
    [btn fadeOut:0.2];
}

- (void)updateSubtitleForTime:(NSInteger)currentTime {
    if(!self.isHideSubtitles){
        int64_t int64Value = (int64_t)currentTime;
        CMTime currentTime = CMTimeMake(int64Value, 1);
        [self updateSubtitleForTime:currentTime subtitles:self.subtitlesArray];
    }
}
- (void)updateSubtitleForTime:(CMTime)date subtitles:(NSArray *)subtitles {
    BOOL subtitleFound = NO; // 用于记录是否找到匹配的字幕
    for (SuperPlayerSubtitle *subtitle in subtitles) {
        if([self isTime:date withinStartTime:subtitle.startTime andEndTime:subtitle.endTime]){
            [self.subtitlesView setDataWithSubtitles:subtitle.text];
            subtitleFound = YES; // 设置标志位，表示找到了匹配的字幕
            break; // 跳出循环，不再继续迭代剩余的字幕
        }
    }
    if (!subtitleFound) {
        //如果没有找到匹配的字幕，则执行相应的处理逻辑（例如清除字幕）
        [self.subtitlesView setDataWithSubtitles:@""];
    }
}
- (BOOL)isTime:(CMTime)time withinStartTime:(CMTime)startTime andEndTime:(CMTime)endTime {
    CFComparisonResult startResult = CMTimeCompare(time, startTime);
    CFComparisonResult endResult = CMTimeCompare(time, endTime);
    
    if((startResult == kCFCompareEqualTo || startResult == kCFCompareGreaterThan) && (endResult == kCFCompareEqualTo || endResult == kCFCompareLessThan)){
        return YES;
    }else{
        return NO;
    }
}
- (void)setIsHideSubtitles:(BOOL)isHideSubtitles {
    _isHideSubtitles = isHideSubtitles;
    self.subtitlesView.hidden = _isHideSubtitles;
}
- (UIButton *)repeatBtn {
    if (!_repeatBtn) {
        _repeatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_repeatBtn setImage:SuperPlayerImage(@"repeat_video") forState:UIControlStateNormal];
        [_repeatBtn addTarget:self action:@selector(repeatBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        _repeatBtn.hidden = YES;
        [self addSubview:_repeatBtn];
        [_repeatBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
        }];
    }
    return _repeatBtn;
}

- (UIButton *)repeatBackBtn {
    if (!_repeatBackBtn) {
        _repeatBackBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_repeatBackBtn setImage:SuperPlayerImage(@"back_full") forState:UIControlStateNormal];
        [_repeatBackBtn addTarget:self action:@selector(controlViewBackAction:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_repeatBackBtn];
        [_repeatBackBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self).offset(15);
            make.top.equalTo(self).offset(15);
            make.width.mas_equalTo(@30);
        }];
    }
    return _repeatBackBtn;
}

- (void)repeatBtnClick:(UIButton *)sender {
    [self.vodPlayer stopPlay];
    [self setVodPlayConfig];
    [self restart];
}

- (MMMaterialDesignSpinner *)spinner {
    if (!_spinner) {
        _spinner = [[MMMaterialDesignSpinner alloc] init];
        _spinner.lineWidth = 1;
        _spinner.duration  = 1;
        _spinner.hidden    = YES;
        _spinner.hidesWhenStopped = YES;
        _spinner.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
        [self addSubview:_spinner];
        [_spinner mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.width.with.height.mas_equalTo(45);
        }];
    }
    return _spinner;
}

- (UIImageView *)coverImageView {
    if (!_coverImageView) {
        _coverImageView = [[UIImageView alloc] init];
        _coverImageView.userInteractionEnabled = YES;
        _coverImageView.contentMode = UIViewContentModeScaleAspectFill;
        _coverImageView.alpha = 1;
        _coverImageView.clipsToBounds = YES;
        [self insertSubview:_coverImageView belowSubview:self.controlView];
        [_coverImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(UIEdgeInsetsZero);
        }];
    }
    return _coverImageView;
}
- (UIImageView *)coverCenterImageView{
    if (!_coverCenterImageView) {
        _coverCenterImageView = [[UIImageView alloc] init];
        _coverCenterImageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.coverImageView addSubview:_coverCenterImageView];
        [_coverCenterImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(UIEdgeInsetsZero);
        }];
    }
    return _coverCenterImageView;
}

- (TXVodPlayer *)vodPlayer {
    if (!_vodPlayer) {
        _vodPlayer = [[TXVodPlayer alloc] init];
        _vodPlayer.vodDelegate = self;
    }
    return _vodPlayer;
}

- (NetWatcher *)netWatcher {
    if (self.disableNetWatcher) {
        return nil;
    }
    if (!_netWatcher) {
        _netWatcher = [[NetWatcher alloc] init];
    }
    return _netWatcher;
}

- (MPVolumeView *)volumeView {
    if(!_volumeView) {
        CGRect frame    = CGRectMake(0, -100, 10, 0);
        _volumeView = [[MPVolumeView alloc] initWithFrame:frame];
        [_volumeView sizeToFit];
    }
    return  _volumeView;
}
@end
