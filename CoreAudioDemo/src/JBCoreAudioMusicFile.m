//
//  JBCoreAudioMusicFile.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/7.
//

#import "JBCoreAudioMusicFile.h"
#import <AudioToolbox/AudioToolbox.h>
#include "JBHelper.h"


@implementation JBCoreAudioMusicFile

+ (void)getMetaData:(AudioFileID )audioFile {
    
    /**
     {
         album = "Dubstep Beach Collection";
         "approximate duration in seconds" = "293.094";     //秒数
         artist = "周传雄";
         comments = "163 key(Don't modify):L64FU3W4.......";
         title = "关不上的窗";
         "track number" = 21;
     }
     */
    UInt32 dicSize = 0;
    OSStatus status = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &dicSize, 0);
    printErr(@"AudioFileGetPropertyInfo kAudioFilePropertyInfoDictionary", status);

    CFDictionaryRef dicRef;
    status = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &dicSize, &dicRef);
    printErr(@"AudioFileGetProperty kAudioFilePropertyInfoDictionary", status);

    NSLog(@"mp3 文件的 meta data: %@", dicRef);
    CFRelease(dicRef);
    
    
    
    // 获取文件的 流信息
    dicSize = 0;
    status = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyFormatList, &dicSize, 0);
    printErr(@"AudioFileGetPropertyInfo kAudioFilePropertyInfoDictionary", status);
    
    AudioFormatListItem *formatList = (AudioFormatListItem *)malloc(dicSize);
    status = AudioFileGetProperty(audioFile, kAudioFilePropertyFormatList, &dicSize, formatList);
    printErr(@"AudioFileGetProperty kAudioFilePropertyInfoDictionary", status);
    
    NSLog(@"音频文件包含的流信息");
    for (int i = 0; i * sizeof(AudioFormatListItem) < dicSize; i += sizeof(AudioFormatListItem)) {
        AudioStreamBasicDescription pasbd = formatList[i].mASBD;
        [JBHelper printASBD:pasbd];
    }
    
    free(formatList);
}

// 获取AudioFileTypeID + AudioFormatID 的格式组合所支持的所有 asbd， 可以用来判断 音频格式的配置是否支持
+ (void)getAudioDesc {
    printf("\n\n\n\n\n枚举 kAudioFileMP3Type + kAudioFormatMPEGLayer3 支持的所有格式\n");
    
    AudioFileTypeID typeID = kAudioFileMP3Type;
    AudioFormatID formatID = kAudioFormatMPEGLayer3;
    
    AudioFileTypeAndFormatID fileTypeAndFormat = {
        .mFileType = typeID,
        .mFormatID = formatID
    };
    
    UInt32 infoSize = 0;
    OSStatus status = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
                                                 sizeof(fileTypeAndFormat),
                                                 &fileTypeAndFormat,
                                                 &infoSize);
    printErr(@"AudioFileGetGlobalInfoSize mp3", status);
    
    
    AudioStreamBasicDescription *asbds = malloc(infoSize);
    status = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
                                    sizeof(fileTypeAndFormat),
                                    &fileTypeAndFormat,
                                    &infoSize,
                                    asbds);
    
    printErr(@"AudioFileGetGlobalInfo mp3", status);
    
    int asbdCount = infoSize / sizeof(AudioStreamBasicDescription);
    for (int i = 0; i< asbdCount; i++) {
        UInt32 format4cc = CFSwapInt32HostToBig(asbds[i].mFormatID);
        //kAudioFileMP3Type + kAudioFormatMPEGLayer3 所支持的所有格式: 0: fileTypeID: 3GPM, mFormatId: .mp3, mFormatFlags: 0, mBitsPerChannel: 0
        NSLog(@"kAudioFileMP3Type + kAudioFormatMPEGLayer3 所支持的所有格式: %d: fileTypeID: %4.4s, mFormatId: %4.4s, mFormatFlags: %u, mBitsPerChannel: %u",
              i,
              (char*)&typeID,
              (char*)&format4cc,
              (unsigned int)asbds[i].mFormatFlags,
              (unsigned int)asbds[i].mBitsPerChannel);
          
    }
    free(asbds);
}
+ (void)startWithURL:(NSURL *)audioURL {
    AudioFileID audioFile;
    OSStatus status =  AudioFileOpenURL((__bridge CFURLRef)audioURL, kAudioFileReadPermission, 0, &audioFile);
    printErr(@"AudioFileOpenURL", status);

    [self getMetaData:audioFile];

    status = AudioFileClose(audioFile);
    printErr(@"AudioFileClose", status);
    
    
}

+ (void)start {
    NSURL *audioURL  = [[NSBundle mainBundle] URLForResource:@"句号" withExtension:@"flac"];
    [self startWithURL:audioURL];
    [self getAudioDesc];
}

@end

