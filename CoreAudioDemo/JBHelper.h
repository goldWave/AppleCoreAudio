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
NSLog(@"==== 出现错误: %@ code: %d(%s)", logStr, (int)status, FourCC2Str(status));\
}

#define JBAssertNoError(inError, inMessage)                                                \
{                                                                            \
SInt32 __Err = (inError);                                                \
if(__Err != 0)                                                            \
{                                                                        \
NSLog(@"==== 出现错误: %@ code: %d(%s)", inMessage, __Err, FourCC2Str(__Err));\
NSAssert(__Err == 0, inMessage);\
}\
}


//#define printErr(logStr, status) \
//        NSLog(@"==== 流程: %@ code: %d(%s)", logStr, (int)status, FourCC2Str(status));


extern  NSString * _Nonnull const JBStopNotification;

NS_ASSUME_NONNULL_BEGIN

@interface JBHelper : NSObject
+ (void)printASBD:(AudioStreamBasicDescription)ASBD;
+ (NSURL *)getOutputPathWithFile:(NSString *)fileName;
+ (void)prisnFFmpegLogWithASBD:(AudioStreamBasicDescription)ASBD path:(NSString *)path preLog:(NSString *)preLog;
@end

NS_ASSUME_NONNULL_END
