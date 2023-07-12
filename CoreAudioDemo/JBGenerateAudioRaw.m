//
//  JBGenerateAudioRaw.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/12.
//

#import "JBGenerateAudioRaw.h"
#import <AudioToolbox/AudioToolbox.h>
#import <MacTypes.h>

@implementation JBGenerateAudioRaw

//创建临时路径
- (NSURL *)getFile:(double)hz shape:(NSString *)shape {
    NSString* fileName = [NSString stringWithFormat:@"%0.3f-%@.aif", hz, shape];

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
            NSLog(@"create SnipFolder rootPath failed!");
        }
    }
    
    
    path =  [path stringByAppendingPathComponent:fileName];

    return [NSURL fileURLWithPath:path];
}

SInt16 generateSineShapeSample(int i, double waveLengthInSamples) {
    assert(i >= 1 && i <= waveLengthInSamples);
   
    SInt16 height = SHRT_MAX * sin(1 * M_PI * (i-1) / waveLengthInSamples);
    return  height;
}
- (NSString *)runCommand:(NSString *)commandToRun
{
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    
    NSArray *arguments = [NSArray arrayWithObjects:
                          @"-c" ,
                          [NSString stringWithFormat:@"%@", commandToRun],
                          nil];
    NSLog(@"run command:%@", commandToRun);
    [task setArguments:arguments];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];

    NSFileHandle *file = [pipe fileHandleForReading];

    [task launch];

    NSData *data = [file readDataToEndOfFile];

    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output;
}


- (void)gerneratePNGFile:(NSURL *)fileURL {
    NSString *outputPng = [fileURL.path stringByReplacingOccurrencesOfString:@"aif" withString:@"png"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPng]) {
        BOOL isSuccess = [[NSFileManager defaultManager] removeItemAtPath:outputPng error:nil];
        if (!isSuccess) {
            NSLog(@"delete png file failed");
        }
    }
    
    
    NSString *cmd = [NSString stringWithFormat:@"/opt/homebrew/bin/ffmpeg -i %@ -filter_complex \"compand,showwavespic=s=2640x2120\" -frames:v 1 %@", fileURL.path, outputPng];
    NSString *output = [self runCommand:cmd];
    NSLog(@"--out png: %@", output);
}

- (void)start {
    
    double hz = 440;
    
    NSString *shape = @"sine"; //sine square saw
    NSURL *fileURL = [self getFile:hz shape:shape];
    NSLog(@"--wirte file:%@", [fileURL path]);
  

    int channelCount = 1;
    
    AudioStreamBasicDescription desc = {
        .mSampleRate = 44100,
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        .mBitsPerChannel = 16,
        .mChannelsPerFrame = channelCount,
        .mFramesPerPacket = 1,
        .mBytesPerFrame = (16 >> 3) * channelCount,
        .mBytesPerPacket = (16 >> 3) * channelCount
    };
    
    AudioFileID audioFile;
    
    OSStatus  status =  AudioFileCreateWithURL((__bridge  CFURLRef)fileURL,
                                               kAudioFileAIFFType,
                                               &desc,
                                               kAudioFileFlags_EraseFile,
                                               &audioFile);
    assert(status == noErr);
    
    long duration = 1.0;
    long maxSampleCount = desc.mSampleRate * duration;
    
    long sampleCount = 1;
    UInt32 bytesToWrite = desc.mBytesPerPacket; //每个样本多少 字节
    
    /**
     因为我们知道我们的样本值需要440在1秒内重复和循环（例如音调A4），
     这意味着我们必须将44,100每秒的样本分配给440循环。或者说，每个周期都需要有44,100 / 440样本。这是在样品中测量的周期或波长。
     */
    double waveLengthInSample = desc.mSampleRate / hz; //代表一个波的长度
    
    NSLog(@"waveLengthInSample: %f", waveLengthInSample);
    
    //轮询填充样本
    while (sampleCount <= maxSampleCount) {
        
        for(int i = 1; i <= waveLengthInSample; i++) {
            SInt16 sample = 0;
            sample = generateSineShapeSample(i, waveLengthInSample);
            sample = CFSwapInt16HostToBig(sample);
            
            SInt64 offset = sampleCount * bytesToWrite;
            status = AudioFileWriteBytes(audioFile, false, offset, &bytesToWrite, &sample);
            assert(status == noErr);
            
            sampleCount++;
        }
    }
    
    status = AudioFileClose(audioFile);
    assert(status == noErr);
    
    NSLog(@"---write samples count: %ld", sampleCount);
    NSLog(@"--wirte file:%@", [fileURL path]);
    NSLog(@"----- done ---- ");
    
    [self gerneratePNGFile: fileURL];
    
}
@end
