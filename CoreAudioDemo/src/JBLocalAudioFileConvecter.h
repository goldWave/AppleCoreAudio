//
//  JBLocalAudioFileConvecter.h
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/21.
//

#import <Foundation/Foundation.h>
#import <CoreAudioTypes/CoreAudioTypes.h>

NS_ASSUME_NONNULL_BEGIN

@interface JBLocalAudioFileConvecter : NSObject
+ (instancetype)sharedInstance;
- (void)start;

- (void)startConvertFlac_to_pcm;
- (void)startConvertPcm_to_flac;
@end

NS_ASSUME_NONNULL_END
