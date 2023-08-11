//
//  ViewController.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/7.
//

#import "ViewController.h"
#import "JBCoreAudioMusicFile.h"
#import "JBGenerateAudioRaw.h"
#import <CoreAudio/CoreAudio.h>
#import "JBPlayLocalMusic_AudioQueue.h"
#import "JBLocalAudioFileConvecter.h"

typedef NS_ENUM(NSInteger, JBAudioType) {
    JBAudioType_None = 0,
    JBAudioType_Read_File,
    JBAudioType_Generate_Raw_data,
    JBAudioType_Play_Music_AudioQueue,
    JBAudioType_MusicFile_2_PCMFile,
    JBAudioType_PCMFile_2_MusicFile,
};

@interface ViewController()

@property (nonatomic, assign) JBAudioType selectType;

@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.selectType = JBAudioType_Read_File;
    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}

- (IBAction)radioBtnClick:(NSButton *)sender {
    self.selectType = (JBAudioType)sender.tag;
}

- (IBAction)startClick:(id)sender {
    switch (self.selectType) {
        case JBAudioType_Read_File:
            // 打印 音频 文件的metadata 和 流信息
            [JBCoreAudioMusicFile  start];
            break;
        case JBAudioType_Generate_Raw_data:
            // 生成 原始的 波形图的 raw data 的音频数据
            [[[JBGenerateAudioRaw alloc] init] start];
            break;
        case JBAudioType_Play_Music_AudioQueue: {
            // 播放本地音频文件
            [[JBPlayLocalMusic_AudioQueue sharedInstance] start];
        }
            break;
        case JBAudioType_MusicFile_2_PCMFile: {
            // 本地编码的音频文件，转换成 pcm 文件
            [[JBLocalAudioFileConvecter sharedInstance] startConvertFlac_to_pcm];
        }
            break;
        case JBAudioType_PCMFile_2_MusicFile: {
            // pcm 文件 转换成  本地编码的音频文件
            [[JBLocalAudioFileConvecter sharedInstance] startConvertPcm_to_flac];
        }
            break;
            
        default:
            break;
    }
}

- (IBAction)stopClick:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:JBStopNotification object:nil];
}


@end
