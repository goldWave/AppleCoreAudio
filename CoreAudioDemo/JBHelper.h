//
//  JBHelper.h
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/7.
//

#import <Foundation/Foundation.h>
#include <AVFoundation/AVFoundation.h>

#include <TargetConditionals.h>

#if TARGET_RT_BIG_ENDIAN
#   define FourCC2Str(fourcc) (const char[]){*((char*)&fourcc), *(((char*)&fourcc)+1), *(((char*)&fourcc)+2), *(((char*)&fourcc)+3),0}
#else
#   define FourCC2Str(fourcc) (const char[]){*(((char*)&fourcc)+3), *(((char*)&fourcc)+2), *(((char*)&fourcc)+1), *(((char*)&fourcc)+0),0}
#endif

#define printErr(logStr, status) \
    if (status != noErr) {\
        NSLog(@"%@ 出现错误: %d(%s)", logStr, (int)status, FourCC2Str(status));\
    }

NS_ASSUME_NONNULL_BEGIN

@interface JBHelper : NSObject
+ (void)printASBD:(AudioStreamBasicDescription)ASBD;
@end

NS_ASSUME_NONNULL_END
