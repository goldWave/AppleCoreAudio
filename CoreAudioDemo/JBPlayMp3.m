//
//  JBPlayMp3.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/17.
//

#import "JBPlayMp3.h"
#include <AudioToolbox/AudioFile.h>
#include "JBHelper.h"
#include <AudioToolbox/AudioToolbox.h>

//每个缓冲区0.5秒的数据量
#define kBufferDurationInSeconds 0.5
#define kNumberBufferSize 3

@interface JBPlayMp3()
{
@public
    AudioFileID _audioFile;
    AudioQueueRef _mQueue;
    UInt32 _bufferByteSize; //缓冲区应有的字节数
    UInt32 _numOfPacketsToRead; // 缓冲区应对应的数据包数量
    AudioStreamPacketDescription *_aspds;
    BOOL _isDone; //是否播放完毕
    Float64 _packagePosition; //播放了多少
}


@property (nonatomic, assign) AudioStreamBasicDescription mASBD;

@end

@implementation JBPlayMp3
- (instancetype)init {
    self = [super init];
    _aspds = NULL;
    _isDone = FALSE;
    return  self;
}
// 开始
- (void)start {
    
    [self openAudioFile];
    [self getASBDInFile];
    
    [self initAudioQueue];
    [self getMetaDataWithFile];
    [self calculateSizeOfTime];
    [self allocPacketArray];
    [self allocAudioQueue];
    
    [self stop];
    
    NSLog(@"播放结束");
}

- (void)stop {
    AudioFileClose(_audioFile);
}

//打开 MP3 文件
- (void)openAudioFile{
    //    NSString *path = [[NSBundle mainBundle] pathForResource:@"周传雄 - 关不上的窗" ofType:@"mp3"];
    //    NSURL *audioURL = [NSURL fileURLWithPath:path];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"周传雄 - 关不上的窗" ofType:@"mp3"];
    NSURL *audioURL = [NSURL URLWithString:@"file:///Users/jimbo/Music/%E7%BD%91%E6%98%93%E4%BA%91%E9%9F%B3%E4%B9%90/G_E_M_%20%E9%82%93%E7%B4%AB%E6%A3%8B%20-%20%E5%8F%A5%E5%8F%B7.flac"];
    //    NSURL *audioURL = [NSURL fileURLWithPath:@"/Users/jimbo/Downloads/曾经我也想过一了百了(Live)-胡彦斌,李巍.128.mp3"];
    
    
    OSStatus status =  AudioFileOpenURL((__bridge  CFURLRef)audioURL, kAudioFileReadPermission, 0, &(_audioFile));
    printErr(@"AudioFileOpenURL", status);
}
static void jbAudioQueueOutputCallback(void * inUserData,
                                       AudioQueueRef inAQ, //对音频队列的引用
                                       AudioQueueBufferRef inBuffer //需要填充的缓冲区播放数据的引用
) {
    
    JBPlayMp3 *playMp3 = (__bridge JBPlayMp3 *)inUserData;
    if (playMp3->_isDone) {
        return;
    }
    
    // 存在局部变量中后，read数据的时候会 自动更新读取到的值
    UInt32 numberBytes = playMp3->_bufferByteSize;
    UInt32 numberPackets = playMp3->_numOfPacketsToRead;
    
    //读取音频包内容，并在最后一个字段中将读取到的数据填充到 inBuffer 中去
    OSStatus status = AudioFileReadPacketData(playMp3->_audioFile,
                                              false,
                                              &numberBytes,
                                              playMp3->_aspds,
                                              playMp3->_packagePosition,
                                              &numberPackets,
                                              inBuffer->mAudioData);
    printErr(@"AudioFileReadPacketData", status);
    if (numberBytes <= 0 || numberPackets <= 0) {
        NSLog(@"数据读取完毕");
        playMp3->_isDone = true;
        return;
    }
    
    inBuffer->mAudioDataByteSize = numberBytes;
    AudioQueueEnqueueBuffer(inAQ,
                            inBuffer,
                            (playMp3->_aspds ? numberPackets : 0),
                            playMp3->_aspds);
    //消费完后，更新下次需要读取的文件的位置
    playMp3->_packagePosition += numberBytes;
    
    
    return;
}

- (void)getASBDInFile {
    /***
     mp3 文件格式， 和PCM 有点差别
     2023-07-17 14:30:13.246099+0800 CoreAudioDemo[91195:21837824] planar:0 bitsPerchannel:0
     2023-07-17 14:30:13.246155+0800 CoreAudioDemo[91195:21837824]
     ASBD:
     mSampleRate = 44100
     mFormatID = 778924083
     mFormatFlags = 0
     mBytesPerPacket = 0
     mFramesPerPacket = 1152
     mBytesPerFrame = 0
     mChannelsPerFrame = 2
     mBitsPerChannel = 0
     mReserved = 0
     */
    AudioStreamBasicDescription asbd;
    UInt32 asbdSize = sizeof(asbd);
    OSStatus status = AudioFileGetProperty(_audioFile, kAudioFilePropertyDataFormat, &asbdSize, &asbd);
    printErr(@"AudioFileOpenURL", status);
    [JBHelper printASBD:asbd];
    self.mASBD = asbd;
}

-  (void)initAudioQueue {
    
    OSStatus status = AudioQueueNewOutput(&_mASBD,
                                          jbAudioQueueOutputCallback,
                                          (__bridge void *)self,
                                          NULL,
                                          NULL,
                                          0,
                                          &_mQueue);
    printErr(@"AudioQueueNewOutput", status);
    
}

// 测试MP3 不行，获取不到 magic data
- (void)getMetaDataWithFile{
    //    //先获取长度
    UInt32 cookieDataSize = 0;
    UInt32 isWriteAble = 0;
    //注意这里是AudioFileGetPropertyInfo
    OSStatus status = AudioFileGetPropertyInfo(_audioFile, kAudioFilePropertyMagicCookieData, &cookieDataSize, &isWriteAble);
    printErr(@"AudioFileGetPropertyInfo kAudioFilePropertyMagicCookieData", status);
    
    if (cookieDataSize <= 0) {
        NSLog(@"AudioFileGetPropertyInfo kAudioFilePropertyMagicCookieData get zero size data");
        return;
    }
    
    //根据长度获取对应的magic data 的内容
    Byte *cookieData = malloc(cookieDataSize *sizeof(Byte));
    //这里是AudioFileGetProperty
    status = AudioFileGetProperty(_audioFile, kAudioFilePropertyMagicCookieData, &cookieDataSize, cookieData);
    printErr(@"AudioFileGetProperty kAudioFilePropertyMagicCookieData", status);
    
    NSLog(@"---magic data size: %i: data: %s", cookieDataSize ,cookieData);
    
    status = AudioQueueSetProperty(_mQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieDataSize);
    printErr(@"AudioQueueSetProperty kAudioQueueProperty_MagicCookie", status);
    free(cookieData);
}

- (void)calculateSizeOfTime{
    
    UInt32 packetSizeUpperBound = 0;
    UInt32 packetSizeUpperBoundSize = sizeof(packetSizeUpperBound);
    // 获取 计算出来的 理论上的 最大 package 大小。非读取文件
    OSStatus status = AudioFileGetProperty(_audioFile,
                                           kAudioFilePropertyPacketSizeUpperBound,
                                           &packetSizeUpperBoundSize,
                                           &packetSizeUpperBound);
    printErr(@"AudioFileGetProperty kAudioFilePropertyPacketSizeUpperBound", status);
    
    //获取kBufferDurationInSeconds时间的包的数量
    UInt32 totalNumerOfPackets = 0;
    if (_mASBD.mFramesPerPacket > 0) {
        //每次时间间隔内需要收集的样本数量
        Float64 totalNumberOfSamples =  _mASBD.mSampleRate * kBufferDurationInSeconds;
        UInt32 totalNumberOfFrames = ceil(totalNumberOfSamples); //将数据向上取整
        totalNumerOfPackets = totalNumberOfFrames / _mASBD.mFramesPerPacket;
    } else {
        // 如果mFramesPerPacket==0，则编解码器在给定时间内没有可预测的数据包大小。
        // 在这种情况下，我们将假设在给定持续时间内最多有 1 个数据包来调整缓冲区大小
        totalNumerOfPackets = 1;
    }
    
    if (_mASBD.mBytesPerPacket > 0) {
        //设置具体值
        _bufferByteSize = self.mASBD.mBytesPerPacket * totalNumerOfPackets;
    } else {
        // 获取理论上最大值
        _bufferByteSize = packetSizeUpperBound * totalNumerOfPackets;
    }
    
    //定义一个最大值，以避免 RAM 消耗过大
    //并定义一个最小值，以确保我们有一个可以在播放时没有问题的缓冲区。太小了会频繁连续从文件读取 IO 消耗比较大
    const int maxBufferSize = 0x100000; // 128KB
    const int minBufferSize = 0x4000;  // 16KB
    //调整成一个中间的适合的值
    if(_bufferByteSize > maxBufferSize) {
        _bufferByteSize = maxBufferSize;
    } else if (_bufferByteSize < minBufferSize) {
        _bufferByteSize = minBufferSize;
    }
    
    //调整后重新计算大小
    _numOfPacketsToRead = _bufferByteSize / packetSizeUpperBound;
    
}


/**
 如果音频基本流描述没有告诉任何有关每个数据包的字节数或每个数据包的帧的信息，
 那么我们就会遇到 VBR 编码或通道大小不等的 CBR 的情况。
 在任何这些情况下，我们都必须为额外的数据包描述分配缓冲区，
 这些描述将在处理音频文件并将其数据包读入缓冲区时填充。
 */
- (void)allocPacketArray {
    BOOL isVBR_or_CBRWithUneualChannelSizes = _mASBD.mBytesPerPacket == 0 || _mASBD.mFramesPerPacket == 0;
    if(isVBR_or_CBRWithUneualChannelSizes) {
        UInt32 size = sizeof(AudioStreamBasicDescription) * _numOfPacketsToRead;
        _aspds = (AudioStreamPacketDescription *)malloc(size);
    } else {
        _aspds = NULL;
    }
}

- (void)allocAudioQueue {
    AudioQueueBufferRef buffers[kNumberBufferSize];
    
    OSStatus status = noErr;
    for(int i = 0 ; i< kNumberBufferSize; i++) {
        status = AudioQueueAllocateBuffer(_mQueue,
                                          _numOfPacketsToRead,
                                          &buffers[i]);
        printErr(@"AudioQueueAllocateBuffer", status);
        
        //手动调用回调， 用音频文件中的音频数据填充缓冲区。
        jbAudioQueueOutputCallback((__bridge  void *)self, _mQueue, buffers[i]);
        if (_isDone) {
            //回调函数中设置为true后，代表剩余时间小于1.5秒
            break;
        }
    }
    if (_isDone) {
        NSLog(@"使用完毕");
        return;
    }
    
    status = AudioQueueStart(_mQueue, NULL);
    printErr(@"AudioQueueStart", status);
    
}

@end
