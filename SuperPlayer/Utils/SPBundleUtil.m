//
//  SPBundleUtil.m
//  SuperPlayer
//
//  Created by Tony on 2020/6/23.
//  Copyright © 2020 annidy. All rights reserved.
//

#import "SPBundleUtil.h"
// 该类用于定位bundle 位置
@interface NoUse : NSObject
@end

@implementation NoUse
@end

@implementation SPBundleUtil
+ (NSString *)spLocalizedStringForKey:(NSString *)key
{
    NSString *bundleResourcePath = [NSBundle bundleForClass:[NoUse class]].resourcePath;
    NSString *assetPath = [bundleResourcePath stringByAppendingPathComponent:@"SuperPlayer.bundle"];
    
    NSBundle *bundle =[NSBundle bundleWithPath:assetPath];
    
    NSString *string = [bundle localizedStringForKey:key value:nil table:nil];
    
    return string;
}
@end
