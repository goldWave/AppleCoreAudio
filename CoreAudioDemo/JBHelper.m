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
    bool planar = (format_flags & kAudioFormatFlagIsNonInterleaved) != 0;
    NSLog(@"planar:%d bitsPerchannel:%d", planar, bits);
    if (format_flags & kAudioFormatFlagIsFloat)
        NSLog(@"kAudioFormatFlagIsFloat");
    
    if (format_flags & kAudioFormatFlagIsBigEndian)
        NSLog(@"kAudioFormatFlagIsBigEndian");
    
    if (format_flags & kAudioFormatFlagIsSignedInteger)
        NSLog(@"kAudioFormatFlagIsSignedInteger");
    if (format_flags & kAudioFormatFlagIsPacked)
        NSLog(@"kAudioFormatFlagIsPacked");
    if (format_flags & kAudioFormatFlagIsAlignedHigh)
        NSLog(@"kAudioFormatFlagIsAlignedHigh");
    if (format_flags & kAudioFormatFlagIsNonInterleaved)
        NSLog(@"kAudioFormatFlagIsNonInterleaved");
    if (format_flags & kAudioFormatFlagIsNonMixable)
        NSLog(@"kAudioFormatFlagIsNonMixable");
    
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
