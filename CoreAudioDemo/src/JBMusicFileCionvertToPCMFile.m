//
//  JBMusicFileCionvertToPCMFile.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/21.
//

#import "JBMusicFileCionvertToPCMFile.h"
#include "JBHelper.h"

@interface JBMusicFileCionvertToPCMFile()
{
@public
}

@property (nonatomic, assign) BOOL isDone; //是否完毕

@end


@implementation JBMusicFileCionvertToPCMFile
+ (instancetype)sharedInstance {
    static JBMusicFileCionvertToPCMFile *sharedSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^(void) {
        sharedSingleton = [[self alloc] init];
    });
    return sharedSingleton;
}

- (instancetype)init {
    self = [super init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stop) name:JBStopNotification object:nil];
    return  self;
}

// 开始
- (void)start {
    if (!self.isDone) {
        return;
    }
}

- (void)stop {
    
}
@end
