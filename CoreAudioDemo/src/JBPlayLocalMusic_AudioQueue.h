//
//  JBPlayLocalMusic_AudioQueue.h
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JBPlayLocalMusic_AudioQueue : NSObject
+ (instancetype)sharedInstance;
- (void)start;
@end

NS_ASSUME_NONNULL_END
