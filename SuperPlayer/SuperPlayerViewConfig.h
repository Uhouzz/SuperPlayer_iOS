//
//  SuperPlayerViewConfig.h
//  SuperPlayer
//
//  Created by annidyfeng on 2018/10/18.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SuperPlayerViewConfig : NSObject
/// 是否镜像，默认NO
@property BOOL mirror;
/// 是否硬件加速，默认YES
@property BOOL hwAcceleration;
/// 播放速度，默认1.0
@property CGFloat playRate;
/// 是否静音，默认NO
@property BOOL mute;
/// 填充模式，默认铺满。 参见 TXLiveSDKTypeDef.h
@property NSInteger renderMode;
/// http头，跟进情况自行设置
@property NSDictionary *headers;
/// 播放器最大缓存个数
@property (nonatomic) NSInteger maxCacheItem;
/// 时移域名，默认为playtimeshift.live.myqcloud.com
@property NSString *playShiftDomain;
/// log打印
@property BOOL enableLog;

///【字段含义】是否自动调整播放器缓存时间，默认值：YES
/// YES：启用自动调整，自动调整的最大值和最小值可以分别通过修改 maxCacheTime 和 minCacheTime 来设置
/// NO：关闭自动调整，采用默认的指定缓存时间(1s)，可以通过修改 cacheTime 来调整缓存时间
@property BOOL bAutoAdjustCacheTime;
///【字段含义】播放器缓存自动调整的最大时间，单位秒，取值需要大于0，默认值：5
@property CGFloat maxAutoAdjustCacheTime;
///【字段含义】播放器缓存自动调整的最小时间，单位秒，取值需要大于0，默认值为1
@property CGFloat minAutoAdjustCacheTime;

@end
