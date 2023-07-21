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
    NSLog(@"planar:%s bitsPerchannel:%d", planar ? "true" : "false", bits);
    NSLog(@"flags: \n\t%@", [arrs componentsJoinedByString:@"\n\t"]);
    return ;
}
+ (void)printASBD:(AudioStreamBasicDescription)ASBD {
    
    [[self class] print_ca_format:ASBD.mFormatFlags bits:ASBD.mBitsPerChannel];
    
    UInt32 formatID4cc = CFSwapInt32HostToBig(ASBD.mFormatID);
    NSMutableString * str = [NSMutableString stringWithString:@"\nASBD: \n"];
    [str appendFormat:@"\tmSampleRate = %.f\n", ASBD.mSampleRate];
    [str appendFormat:@"\tmFormatID = %u(%4.4s)\n", (unsigned int)ASBD.mFormatID, (char *)&formatID4cc];
    [str appendFormat:@"\tmFormatFlags = %u\n", (unsigned int)ASBD.mFormatFlags];
    [str appendFormat:@"\tmBytesPerPacket = %u\n", ASBD.mBytesPerPacket];
    [str appendFormat:@"\tmFramesPerPacket = %u\n", ASBD.mFramesPerPacket];
    [str appendFormat:@"\tmBytesPerFrame = %u\n", ASBD.mBytesPerFrame];
    [str appendFormat:@"\tmChannelsPerFrame = %u\n", ASBD.mChannelsPerFrame];
    [str appendFormat:@"\tmBitsPerChannel = %u\n", ASBD.mBitsPerChannel];
    [str appendFormat:@"\tmReserved = %i\n", ASBD.mReserved];
    NSLog(@"%@", str);
}
@end
