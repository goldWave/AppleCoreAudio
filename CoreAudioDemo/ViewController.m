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
#import "JBPlayLocalMusicFile.h"

typedef NS_ENUM(NSInteger, JBAudioType) {
    JBAudioType_None = 0,
    JBAudioType_Read_File,
    JBAudioType_Generate_Raw_data,
    JBAudioType_Play_Mp3,
};

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}

- (IBAction)radioBtnClick:(NSButton *)sender {
    JBAudioType seletctTag = (JBAudioType)sender.tag;
    
    switch (seletctTag) {
        case JBAudioType_Read_File:
            // 打印 音频 文件的metadata 和 流信息
            [[[JBCoreAudioMusicFile alloc] init] start];
            break;
        case JBAudioType_Generate_Raw_data:
            // 生成 原始的 波形图的 raw data 的音频数据
            [[[JBGenerateAudioRaw alloc] init] start];
            break;
        case JBAudioType_Play_Mp3: {
            [[JBPlayLocalMusicFile sharedInstance] start];
        }
            break;
        default:
            break;
    }
    
}

- (IBAction)startClick:(id)sender {
}

- (IBAction)stopClick:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:JBStopNotification object:nil];
}


@end
