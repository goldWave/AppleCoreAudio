//
//  JBCoreAudioMusicFile.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/7.
//

#import "JBCoreAudioMusicFile.h"
#import <AudioToolbox/AudioToolbox.h>

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

@implementation JBCoreAudioMusicFile

- (void)start {
    NSString *mp3Str = @"/Users/jimbo/Music/网易云音乐/周传雄 - 关不上的窗.mp3";
    NSURL *mp3URL = [NSURL fileURLWithPath:mp3Str];
    
    AudioFileID audioFile;
    OSStatus status =  AudioFileOpenURL((__bridge CFURLRef)mp3URL, kAudioFileReadPermission, 0, &audioFile);
    printErr(@"AudioFileOpenURL", status);
    
    UInt32 dicSize = 0;
    status = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &dicSize, 0);
    printErr(@"AudioFileGetPropertyInfo kAudioFilePropertyInfoDictionary", status);
    
    CFDictionaryRef dicRef;
    status = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &dicSize, &dicRef);
    printErr(@"AudioFileGetProperty kAudioFilePropertyInfoDictionary", status);
    
    NSLog(@"mp3 dic: %@", dicRef);
    CFRelease(dicRef);
    
    status = AudioFileClose(audioFile);
    printErr(@"AudioFileClose", status);
}

@end

