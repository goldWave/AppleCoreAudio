//
//  JBPlayLocalMusic_AudioQueue.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/17.
//

#import "JBPlayLocalMusic_AudioQueue.h"
#include <AudioToolbox/AudioFile.h>
#include "JBHelper.h"
#include <AudioToolbox/AudioToolbox.h>

//每个缓冲区0.5秒的数据量
#define kBufferDurationInSeconds 0.5
//分配三个缓冲区
#define kNumberBuffer 3

@interface JBPlayLocalMusic_AudioQueue()
{
@public
    AudioFileID _audioFile;
    AudioQueueRef _mQueue;
    AudioStreamPacketDescription *_aspds; //从文件中读取的包秒数，每次读取后将其传入 AudioQueue中，以便能正确解码和播放
}

@property (nonatomic, assign) AudioStreamBasicDescription mASBD;
@property (nonatomic, assign) BOOL isRunning; //是否正在播放
@property (nonatomic, assign) UInt32 byteSizeInBuffer; //缓冲区应有的字节数（0.5秒内）
@property (nonatomic, assign) UInt32 packetsNumInBuffer; // 缓冲区应对应的数据包数量（0.5秒内）
@property (nonatomic, assign) Float64 readOffsetOfPackets; //读取了多少 packets
@end

@implementation JBPlayLocalMusic_AudioQueue

+ (instancetype)sharedInstance {
    static JBPlayLocalMusic_AudioQueue *sharedSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^(void) {
        sharedSingleton = [[self alloc] init];
    });
    return sharedSingleton;
}

- (instancetype)init {
    self = [super init];
    _aspds = NULL;
    _isRunning = false;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stop) name:JBStopNotification object:nil];
    return  self;
}

// 开始
- (void)start {
    if (self.isRunning) {
        //播放中
        return;
    }
    self.isRunning = YES;
    [self openAudioFile];
    [self getASBDInFile];
    
    //init audio queue by output param
    OSStatus status = AudioQueueNewOutput(&_mASBD,
                                          jbAudioQueueOutputCallback,
                                          (__bridge void *)self,
                                          NULL,
                                          NULL,
                                          0,
                                          &_mQueue);
    printErr(@"AudioQueueNewOutput", status);
    //读取文件的magic cookie，然后设置到 Audio queue 里面去
    [self setFileMetaDataToAudioQueue];
    
    //计算从文件读取包数据的，每次需要的大小 （0.5秒时间内）
    [self calculateSizeOfTime];
    
    //开辟 ASPD 数组内存
    [self allocPacketArray];
    
    //开辟Audio Queue的缓冲队列
    [self allocAudioQueue];
    
    if (!self.isRunning) {
        NSLog(@"使用完毕");
        [self stop];
        return;
    }
    status = AudioQueueStart(_mQueue, NULL);
    printErr(@"AudioQueueStart", status);
}

- (void)stop {
    
    OSStatus status = AudioQueueStop(_mQueue, true);
    printErr(@"AudioQueueStop", status);
    status = AudioQueueDispose(_mQueue, true);
    printErr(@"AAudioQueueDispose", status);
    if(_aspds) {
        free(_aspds);
    }
    status = AudioFileClose(_audioFile);
    printErr(@"AudioFileClose", status);
    self.isRunning = NO;
    NSLog(@"播放结束");
}

//打开 音频 文件
- (void)openAudioFile{
    NSURL *audioURL  = [[NSBundle mainBundle] URLForResource:@"句号" withExtension:@"flac"];
    OSStatus status =  AudioFileOpenURL((__bridge  CFURLRef)audioURL, kAudioFileReadPermission, 0, &(_audioFile));
    printErr(@"AudioFileOpenURL", status);
}

static void jbAudioQueueOutputCallback(void * inUserData,
                                       AudioQueueRef inAQ, //对音频队列的引用
                                       AudioQueueBufferRef inBuffer //需要填充的缓冲区播放数据的引用
) {
    
    JBPlayLocalMusic_AudioQueue *playClass = (__bridge JBPlayLocalMusic_AudioQueue *)inUserData;
    if (!playClass.isRunning) {
        return;
    }
    
    // 存在局部变量中后，read数据的时候会 自动更新读取到的值
    UInt32 numberBytes = playClass.byteSizeInBuffer;
    UInt32 numberPackets = playClass.packetsNumInBuffer;
    
    //读取音频包内容，并在最后一个字段中将读取到的数据填充到 inBuffer 中去
    OSStatus status = AudioFileReadPacketData(playClass->_audioFile,
                                              false,
                                              &numberBytes,
                                              playClass->_aspds,
                                              playClass.readOffsetOfPackets,
                                              &numberPackets,
                                              inBuffer->mAudioData);
    printErr(@"AudioFileReadPacketData", status);
    if (numberBytes <= 0 || numberPackets <= 0) {
        NSLog(@"数据读取完毕");
        playClass.isRunning = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [playClass stop];
        });
        return;
    }
    
    inBuffer->mAudioDataByteSize = numberBytes;
    AudioQueueEnqueueBuffer(inAQ,
                            inBuffer,
                            (playClass->_aspds ? numberPackets : 0),
                            playClass->_aspds);
    //消费完后，更新下次需要读取的文件的位置
    playClass.readOffsetOfPackets += numberPackets;
}

- (void)getASBDInFile {
    /***
     mp3 flac 文件格式， 和PCM 有点差别
     2023-07-21 14:54:49.042644+0800 CoreAudioDemo[2536:5829281] planar:false bitsPerchannel:0
     2023-07-21 14:54:49.042694+0800 CoreAudioDemo[2536:5829281] flags:
         kAppleLosslessFormatFlag_16BitSourceData
         kAppleLosslessFormatFlag_24BitSourceData
         kAudioFormatFlagIsFloat
         kLinearPCMFormatFlagsSampleFractionShift
     2023-07-21 14:54:49.042731+0800 CoreAudioDemo[2536:5829281]
     ASBD:
         mSampleRate = 44100
         mFormatID = 1718378851(flac)
         mFormatFlags = 1
         mBytesPerPacket = 0
         mFramesPerPacket = 4096
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

// MP3获取不到 magic cookie
- (void)setFileMetaDataToAudioQueue{
    //先获取长度
    UInt32 cookieDataSize = 0;
    UInt32 isWriteAble = 0;
    //注意这里是AudioFileGetPropertyInfo， 获取长度和是否可以写
    OSStatus status = AudioFileGetPropertyInfo(_audioFile, kAudioFilePropertyMagicCookieData, &cookieDataSize, &isWriteAble);
    
    //有些没有 magic cookie ，所以不管
    if (status != noErr) {
        NSLog(@"magic cookie 不存在，忽略掉");
        return;
    }
    
    if (cookieDataSize <= 0) {
        NSLog(@"AudioFileGetPropertyInfo kAudioFilePropertyMagicCookieData get zero size data");
        return;
    }
    
    //根据长度获取对应的magic data 的内容
    Byte *cookieData = malloc(cookieDataSize *sizeof(Byte));
    //这里是AudioFileGetProperty
    status = AudioFileGetProperty(_audioFile, kAudioFilePropertyMagicCookieData, &cookieDataSize, cookieData);
    printErr(@"AudioFileGetProperty kAudioFilePropertyMagicCookieData", status);
    
    //将获取的MagicCookie 设置到 AudioQueue 中
    status = AudioQueueSetProperty(_mQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieDataSize);
    printErr(@"AudioQueueSetProperty kAudioQueueProperty_MagicCookie", status);
    
    // malloc 后必须 free
    free(cookieData);
}

- (void)calculateSizeOfTime{
    
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
    
    UInt32 packetSizeUpperBound = 0;
    UInt32 packetSizeUpperBoundSize = sizeof(packetSizeUpperBound);
    // 获取 计算出来的 理论上的 最大 package 大小。非读取文件
    OSStatus status = AudioFileGetProperty(_audioFile,
                                           kAudioFilePropertyPacketSizeUpperBound,
                                           &packetSizeUpperBoundSize,
                                           &packetSizeUpperBound);
    printErr(@"AudioFileGetProperty kAudioFilePropertyPacketSizeUpperBound", status);
    
    if (_mASBD.mBytesPerPacket > 0) {
        //设置具体值
        self.byteSizeInBuffer = self.mASBD.mBytesPerPacket * totalNumerOfPackets;
    } else {
        // 获取理论上最大值
        self.byteSizeInBuffer = packetSizeUpperBound * totalNumerOfPackets;
    }
    
    //定义一个最大值，以避免 RAM 消耗过大
    //并定义一个最小值，以确保我们有一个可以在播放时没有问题的缓冲区。太小了会频繁连续从文件读取 IO 消耗比较大
    const int maxBufferSize = 0x100000; // 128KB
    const int minBufferSize = 0x4000;  // 16KB
    //调整成一个中间的适合的值
    if(self.byteSizeInBuffer > maxBufferSize) {
        self.byteSizeInBuffer = maxBufferSize;
    } else if (self.byteSizeInBuffer < minBufferSize) {
        self.byteSizeInBuffer = minBufferSize;
    }
    
    //调整后重新计算大小， 这样可能多分配内存，但至少不会内存越界
    self.packetsNumInBuffer = self.byteSizeInBuffer / packetSizeUpperBound;
}


/**
 如果音频基本流描述没有告诉任何有关每个数据包的字节数或每个数据包的帧的信息，
 那么我们就会遇到 VBR 编码或通道大小不等的 CBR 的情况。
 在任何这些情况下，我们都必须为额外的数据包描述分配缓冲区，
 这些描述将在处理音频文件并将其数据包读入缓冲区时填充。
 */
- (void)allocPacketArray {
    BOOL isNeedASPD = _mASBD.mBytesPerPacket == 0 || _mASBD.mFramesPerPacket == 0;
    if(isNeedASPD) {
        _aspds = (AudioStreamPacketDescription *)calloc(sizeof(AudioStreamPacketDescription), _packetsNumInBuffer);
    } else {
        _aspds = NULL;
    }
}

- (void)allocAudioQueue {
    AudioQueueBufferRef buffers[kNumberBuffer];
    
    OSStatus status = noErr;
    for(int i = 0 ; i< kNumberBuffer; i++) {
        status = AudioQueueAllocateBuffer(_mQueue,
                                          self.byteSizeInBuffer,
                                          &buffers[i]);
        printErr(@"AudioQueueAllocateBuffer", status);
        
        //手动调用回调，用音频文件中的音频数据填充缓冲区。
        //后续调用AudioQueueStart后，会自动触发回调进行调用
        jbAudioQueueOutputCallback((__bridge  void *)self, _mQueue, buffers[i]);
        if (!self.isRunning) {
            //回调函数中设置为true后，代表剩余时间小于1.5秒
            break;
        }
    }
}

@end
