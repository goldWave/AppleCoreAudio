//
//  JBHelper.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/7.
//

#import "JBHelper.h"

NSString *const JBStopNotification = @"JBStopNotification";

@implementation JBHelper

+ (void)print_ca_format:(UInt32)format_flags bits:(UInt32)bits
{
    static NSDictionary *flags = @{
        @"kAudioFormatFlagIsFloat"                  : @(kAudioFormatFlagIsFloat),
        @"kAudioFormatFlagIsBigEndian"              : @(kAudioFormatFlagIsBigEndian),
        @"kAudioFormatFlagIsSignedInteger"          : @(kAudioFormatFlagIsSignedInteger),
        @"kAudioFormatFlagIsPacked"                 : @(kAudioFormatFlagIsPacked),
        @"kAudioFormatFlagIsAlignedHigh"            : @(kAudioFormatFlagIsAlignedHigh),
        @"kAudioFormatFlagIsNonInterleaved"         : @(kAudioFormatFlagIsNonInterleaved),
        @"kAudioFormatFlagIsNonMixable"             : @(kAudioFormatFlagIsNonMixable),
        @"kAudioFormatFlagsAreAllClear"             : @(kAudioFormatFlagsAreAllClear),
        @"kLinearPCMFormatFlagsSampleFractionShift" : @(kLinearPCMFormatFlagsSampleFractionShift),
        @"kLinearPCMFormatFlagsSampleFractionMask"  : @(kLinearPCMFormatFlagsSampleFractionMask),
        @"kAppleLosslessFormatFlag_16BitSourceData" : @(kAppleLosslessFormatFlag_16BitSourceData),
        @"kAppleLosslessFormatFlag_20BitSourceData" : @(kAppleLosslessFormatFlag_20BitSourceData),
        @"kAppleLosslessFormatFlag_24BitSourceData" : @(kAppleLosslessFormatFlag_24BitSourceData),
        @"kAppleLosslessFormatFlag_32BitSourceData" : @(kAppleLosslessFormatFlag_32BitSourceData)
    };
    
    NSMutableArray *arrs = @[].mutableCopy;
    for (NSString *key in flags) {
        int flagValue =  [flags[key] intValue];
        if ((flagValue & format_flags) == flagValue) {
            [arrs addObject:key];
        }
    }
    
    bool planar = (format_flags & kAudioFormatFlagIsNonInterleaved) == format_flags;
    printf("planar:%s bitsPerchannel:%d\n", planar ? "true" : "false", bits);
    printf("flags: \n\t%s\n", [arrs componentsJoinedByString:@"\n\t"].UTF8String);
    return ;
}
+ (void)printASBD:(AudioStreamBasicDescription)ASBD {
    
    [[self class] print_ca_format:ASBD.mFormatFlags bits:ASBD.mBitsPerChannel];
    
    UInt32 formatID4cc = CFSwapInt32HostToBig(ASBD.mFormatID);
    NSMutableString * str = [NSMutableString stringWithString:@"\nASBD: \n"];
    [str appendFormat:@"\tmSampleRate = %.f\n", ASBD.mSampleRate];
    [str appendFormat:@"\tmFormatID = %u(%4.4s)\n", (unsigned int)ASBD.mFormatID, (char *)&formatID4cc];
    [str appendFormat:@"\tmFormatFlags = %u\n", (unsigned int)ASBD.mFormatFlags];
    [str appendFormat:@"\tmBytesPerPacket = %u\t(%s)\n", ASBD.mBytesPerPacket, ASBD.mBytesPerPacket > 0 ? "CBR" : "VBR"];
    [str appendFormat:@"\tmFramesPerPacket = %u\n", ASBD.mFramesPerPacket];
    [str appendFormat:@"\tmBytesPerFrame = %u\n", ASBD.mBytesPerFrame];
    [str appendFormat:@"\tmChannelsPerFrame = %u\n", ASBD.mChannelsPerFrame];
    [str appendFormat:@"\tmBitsPerChannel = %u\n", ASBD.mBitsPerChannel];
    [str appendFormat:@"\tmReserved = %i\n", ASBD.mReserved];
    printf("%s\n", [str UTF8String]);
}

//创建临时路径
+ (NSURL *)getOutputPathWithFile:(NSString *)fileName {

    NSString *path = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(
        NSCachesDirectory, NSUserDomainMask, YES);
    if ([paths count])
    {
        NSString *bundleName =
            [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        path = [[paths objectAtIndex:0] stringByAppendingPathComponent:bundleName];
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
       BOOL isSuccess = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (!isSuccess) {
            NSLog(@"临时路径创建失败");
        }
    }
    
    path =  [path stringByAppendingPathComponent:fileName];

    return [NSURL fileURLWithPath:path];
}


+ (void)prisnFFmpegLogWithASBD:(AudioStreamBasicDescription)ASBD path:(NSString *)path preLog:(NSString *)preLog {
    if ([path hasSuffix:@".caf"]) {
        NSString *log = [NSString stringWithFormat:@"%@ ffplay %@",preLog, path];
        printf("%s\n", log.UTF8String);
        return;;
    }
    bool planar = (ASBD.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    if (planar) {
        NSLog(@"not support planar pcm");
        return;
    }
    
    NSString *typeString = @"f";
    if (ASBD.mFormatFlags & kAudioFormatFlagIsSignedInteger) {
        typeString = @"s";
    }
    
    NSString *isBigString = @"le";
    if (ASBD.mFormatFlags & kLinearPCMFormatFlagIsBigEndian) {
        isBigString =  @"be";
    }
    
    NSString *formatString = [NSString stringWithFormat:@"%@%d%@", typeString, ASBD.mBitsPerChannel, isBigString];
    
    NSString *log = [NSString stringWithFormat:@"%@ ffplay -ar %i -ac %d -f %@ %@",preLog, (int)ASBD.mSampleRate, ASBD.mChannelsPerFrame,formatString, path];
    printf("%s\n", log.UTF8String);
}
@end
