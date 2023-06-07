//
//  SuperPlayerSubtitlesView.m
//  AFNetworking
//
//  Created by 马壮 on 2023/6/5.
//

#import "SuperPlayerSubtitlesView.h"
#import <Masonry/Masonry.h>
@interface SuperPlayerSubtitlesView ()

@property (nonatomic ,strong)UILabel *subtitle;

@end
@implementation SuperPlayerSubtitlesView


- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self){
        self.layer.backgroundColor = [UIColor colorWithRed:0/255.0 green:0/255.0 blue:0/255.0 alpha:0.3].CGColor;
        self.layer.cornerRadius = 5;
        [self setUI];
    }
    return self;
}
- (void)setUI{
    [self addSubview:self.subtitle];
    [self.subtitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self).offset(5);
        make.top.mas_equalTo(self).offset(3);
        make.right.mas_equalTo(self).offset(-5);
        make.bottom.mas_equalTo(self).offset(-3);
        
    }];
}
- (UILabel *)subtitle {
    if(!_subtitle){
        _subtitle = [[UILabel alloc] init];
        _subtitle.font = [UIFont systemFontOfSize:12];
        _subtitle.textColor = [UIColor whiteColor];
        _subtitle.numberOfLines = 0;
        _subtitle.textAlignment = NSTextAlignmentCenter;
        _subtitle.text = @"这是字幕";
    }
    return _subtitle;
}
- (void)setDataWithSubtitles:(NSString *)subtitles {
    if([subtitles isEqualToString:@"WEBVTT"]){
        self.hidden = YES;
        self.subtitle.text = @"";
    }else{
        self.hidden = NO;
        self.subtitle.text = subtitles;
        
    }
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
