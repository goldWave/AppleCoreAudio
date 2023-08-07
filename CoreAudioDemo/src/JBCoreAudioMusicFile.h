//
//  JBCoreAudioMusicFile.h
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/7.
//

#import <Foundation/Foundation.h>
#import "JBHelper.h"

NS_ASSUME_NONNULL_BEGIN

@interface JBCoreAudioMusicFile : NSObject
+ (void)start;
+ (void)startWithURL:(NSURL *)audioURL;
@end

NS_ASSUME_NONNULL_END
