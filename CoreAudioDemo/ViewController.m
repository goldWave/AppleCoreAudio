//
//  ViewController.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/7.
//

#import "ViewController.h"
#import "JBCoreAudioMusicFile.h"
#import "JBGenerateAudioRaw.h"

typedef NS_ENUM(NSInteger, JBAudioType) {
    JBAudioType_None = 0,
    JBAudioType_Read_File,
    JBAudioType_Generate_Raw_data
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
            [[[JBCoreAudioMusicFile alloc] init] start];
            break;
        case JBAudioType_Generate_Raw_data:
            [[[JBGenerateAudioRaw alloc] init] start];
            break;
        default:
            break;
    }
    
}


@end
