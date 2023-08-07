//
//  JBLicalAudioFileConvecter.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/21.
//

#import "JBLicalAudioFileConvecter.h"
#include "JBHelper.h"
#include <AudioToolbox/AudioToolbox.h>

#define KOutputName @"output.caf"

#define  inMinPacketNumToRead 1000

@interface JBLicalAudioFileConvecter()
{
@public
    AudioFileID _inFile;
    AudioFileID _outFile; //输出文件1
    FILE *_outPCMFile; //输出文件2
    char * _inBuffer;
}

@property (atomic, assign) BOOL isRunning;

@property (nonatomic, assign) AudioStreamBasicDescription inASBD;
@property (nonatomic, assign) UInt32 inMaxSizePerPacket; //输入文件包里面的最大尺寸的包的尺寸
@property (nonatomic, assign) UInt32 inNumPacketPerRead; //输入文件的，自己malloc的buffer内能容纳的最大packet数量
@property (nonatomic, assign) UInt32 inPacketReadIndex; //输入文件读取的包的下标
@property (nonatomic, assign) AudioStreamPacketDescription *inASPDs;

@property (nonatomic, assign) AudioStreamBasicDescription outASBD;
@property (nonatomic, assign) AudioStreamPacketDescription *outASPDs;

@property (nonatomic, strong) dispatch_queue_t workQueue;
@end

static void getAudioFileProperty(AudioFileID fileID, AudioFilePropertyID inPropertyID, void *outData, NSString *logID) {
    UInt32 isWriteAble = 0;
    UInt32 size = sizeof(UInt32);
    // 获取属性所需要的长度
    OSStatus status = AudioFileGetPropertyInfo(fileID, inPropertyID, &size, &isWriteAble);
    printErr(([NSString stringWithFormat:@"AudioFileGetPropertyInfo %@", logID]), status);
    
    //通过上一步获取的长度，填充取到的值
    status = AudioFileGetProperty(fileID, inPropertyID, &size, outData);
    printErr(([NSString stringWithFormat:@"AudioFileGetProperty %@", logID]), status);
}

static void getAudioConverterProperty(AudioConverterRef audioConverter, AudioConverterPropertyID inPropertyID, void *outData, NSString *logID) {
    Boolean isWriteAble = false;
    UInt32 size = sizeof(UInt32);
    // 获取属性所需要的长度
    OSStatus status = AudioConverterGetPropertyInfo(audioConverter, inPropertyID, &size, &isWriteAble);
    printErr(([NSString stringWithFormat:@"AudioConverterGetPropertyInfo %@", logID]), status);
    
    //通过上一步获取的长度，填充取到的值
    status = AudioConverterGetProperty(audioConverter, inPropertyID, &size, outData);
    printErr(([NSString stringWithFormat:@"AudioConverterGetProperty %@", logID]), status);
}

@implementation JBLicalAudioFileConvecter
+ (instancetype)sharedInstance {
    static JBLicalAudioFileConvecter *sharedSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^(void) {
        sharedSingleton = [[self alloc] init];
    });
    return sharedSingleton;
}

- (instancetype)init {
    self = [super init];
    self.isRunning = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stop) name:JBStopNotification object:nil];
    self.workQueue = dispatch_queue_create("jimbo audio converter", DISPATCH_QUEUE_SERIAL);
    return  self;
}

// 开始
- (void)start {
    if (self.isRunning) {
        return;
    };
    self.isRunning = YES;
    self.inASPDs = NULL;
    self.outASPDs = NULL;
    self.inASPDs = NULL;
    _outPCMFile = NULL;
    _inBuffer = NULL;
    
    dispatch_async(self.workQueue, ^{
        [self workSubThread];
    });
}

- (void)stop {
    self.isRunning = NO;
}

- (void)workSubThread {
    
    //打开 输入 音频 文件
    NSURL *audioURL  = [[NSBundle mainBundle] URLForResource:@"句号_10s" withExtension:@"flac"];
    JBAssertNoError(AudioFileOpenURL((__bridge  CFURLRef)audioURL, kAudioFileReadPermission, 0, &_inFile), @"AudioFileOpenURL");
    
    //获取输入文件的 ASBD
    UInt32 size = sizeof(AudioStreamBasicDescription);
    JBAssertNoError(AudioFileGetProperty(_inFile, kAudioFilePropertyDataFormat, &size, &_inASBD),@"AudioFileGetProperty kAudioFilePropertyDataFormat");
    
    [self fillUpOutASBDWithInputFile];
    
    //打开 输出 音频 文件
    NSURL *outURL = [JBHelper getOutputPathWithFile:KOutputName];
    JBAssertNoError(AudioFileCreateWithURL((__bridge CFURLRef)outURL, kAudioFileCAFType, &_outASBD, kAudioFileFlags_EraseFile, &_outFile),@"AudioFileCreateWithURL");
    
    NSURL *outURL_cfile = [JBHelper getOutputPathWithFile:@"pcm_output.pcm"];
    NSString *pathStr_cfile = [outURL_cfile.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    if (_outPCMFile == NULL) {
        _outPCMFile = fopen([pathStr_cfile UTF8String], "wb++");
    }
//    printf("\n\ninASBD\n");
//    [JBHelper printASBD:self.inASBD];
//    printf("\n\noutASBD\n");
//    [JBHelper printASBD:self.outASBD];
    
    //创建转换对象
    AudioConverterRef audioConverter;
    JBAssertNoError(AudioConverterNew(&_inASBD, &_outASBD, &audioConverter),@"AudioConverterNew");
    
    [self setInFileMetaDataToAudioConverter:audioConverter];
    
    //重新从 Audio Convert 获取被校正过的 ASBD数据
    
    JBAssertNoError(AudioConverterGetProperty(audioConverter, kAudioConverterCurrentInputStreamDescription, &size, &_inASBD), @"kAudioConverterCurrentInputStreamDescription get infile");
    JBAssertNoError(AudioConverterGetProperty(audioConverter, kAudioConverterCurrentOutputStreamDescription, &size, &_outASBD), @"kAudioConverterCurrentInputStreamDescription get outfile");
    
    printf("\n\n    after inASBD\n");
    [JBHelper printASBD:self.inASBD];
    printf("\n\n    after outASBD\n");
    [JBHelper printASBD:self.outASBD];
    
    UInt32 inBufferSize = 4096*8;
    _inBuffer = malloc(inBufferSize);
    
    if (self.inASBD.mBytesPerPacket == 0) {
        //输入文件的 单个packet 理论上的最大大小。
        
        /**
         据了解 kAudioFilePropertyPacketSizeUpperBound 不会打开整个文件，只是预测
         kAudioFilePropertyMaximumPacketSize 有可能会打开文件来计算
         */
        
        UInt32 inSizePerPacket = 0;   //18466 in this file aac
        size = sizeof(inSizePerPacket);
        JBAssertNoError(AudioFileGetProperty(_inFile, kAudioFilePropertyPacketSizeUpperBound, &size, &inSizePerPacket), @"kAudioFilePropertyPacketSizeUpperBound");
        self.inMaxSizePerPacket = inSizePerPacket;
        //每次读取的packet的数量，必须根据我们 输入缓冲区的大小，来决定
        self.inNumPacketPerRead = inBufferSize / inSizePerPacket;
        // VBR 可变比特率
        self.inASPDs = calloc(self.inNumPacketPerRead, sizeof(AudioStreamPacketDescription));
    } else {
        // CBR 固定比特率
        self.inMaxSizePerPacket = self.inASBD.mBytesPerPacket;
        self.inNumPacketPerRead = inBufferSize / self.inASBD.mBytesPerPacket;
        self.inASPDs = NULL;
    }
    
    /**  配置输入信息  */
    char *outBuffer;
    UInt32 outBufferSize = 4096*8;
    outBuffer = (char *)malloc(outBufferSize);
    memset(outBuffer, 0, outBufferSize);

    UInt32 outSizePerPacket = self.outASBD.mBytesPerPacket; //4
    
    //理论上输入缓冲区能容纳下的最大 packet 数量
    UInt numPaketPerOut = outBufferSize / outSizePerPacket;
    
    if(outSizePerPacket == 0) {
        //输出的 VBR， 需要重新计算每个包的 包大小
        getAudioConverterProperty(audioConverter,
                                  kAudioConverterPropertyMaximumOutputPacketSize,
                                  &outSizePerPacket,
                                  @"kAudioConverterPropertyMaximumOutputPacketSize");
        numPaketPerOut = outBufferSize / outSizePerPacket;
        self.outASPDs = calloc(numPaketPerOut, sizeof(AudioStreamPacketDescription));
    }
    
    //TOTO: 写 magic cookie 到输出文件
    
    if(self.inASBD.mChannelsPerFrame > 2) {
        //TODO: 多channel
        NSAssert(false, @"需要写入channel layout 到audio convert 中才能正常转换");
    }
    
    
    NSLog(@"---每次输入的包数量：numPaketPerOut: %d", numPaketPerOut);
    NSLog(@"---outSizePerPacket: %d", outSizePerPacket);
    NSLog(@"---outBufferSize: %d", outBufferSize);
    
    UInt64 totalOutputFrames_debug = 0;
    UInt32 outFilePacketOffset = 0;
    //阻塞式
    while (true) {
        if (!_isRunning) {
            break;
        }
        
        AudioBufferList outBufferList = {0};
        outBufferList.mNumberBuffers = 1;
        outBufferList.mBuffers[0].mNumberChannels = self.outASBD.mChannelsPerFrame;
        outBufferList.mBuffers[0].mDataByteSize = outBufferSize;
        outBufferList.mBuffers[0].mData = outBuffer;
        
        //malloc的输入缓冲区能够装下的最大包数量
        UInt32 ioOutDataPacketsPerOut = numPaketPerOut;
        OSStatus status = AudioConverterFillComplexBuffer(audioConverter,
                                                          JBAudioConverterCallback,
                                                          (__bridge void *)self,
                                                          &ioOutDataPacketsPerOut,
                                                          &outBufferList,
                                                          self.outASPDs);
        printErr(@"AudioConverterFillComplexBuffer", status);
        
        if(status != noErr) {
            NSLog(@"AudioConverterFillComplexBuffer--- 失败了，退出");
            break;
        } else if (ioOutDataPacketsPerOut == 0) {
            //EOF, 文件读完了
            status = noErr;
            break;
        }
        
        NSLog(@"convert 输出：写入包数量：%d, offset:%d size:%d,", ioOutDataPacketsPerOut, outFilePacketOffset, outBufferList.mBuffers[0].mDataByteSize);

        JBAssertNoError(AudioFileWritePackets(_outFile,
                                              false,
                                              outBufferList.mBuffers[0].mDataByteSize,
                                              self.outASPDs,
                                              outFilePacketOffset,
                                              &ioOutDataPacketsPerOut,
                                              outBuffer),
                        @"AudioFileWritePackets");
        
        fwrite((char *)outBufferList.mBuffers[0].mData, sizeof(char), outBufferList.mBuffers[0].mDataByteSize, _outPCMFile);

        if (self.outASBD.mBytesPerPacket) {
            totalOutputFrames_debug += (ioOutDataPacketsPerOut * self.outASBD.mFramesPerPacket);
        } else if (!self.outASPDs) {
            for(UInt32 i= 0; i < ioOutDataPacketsPerOut; i++) {
                totalOutputFrames_debug += self.outASPDs[i].mVariableFramesInPacket;
            }
        }
        
        NSLog(@"总共写入frame数量: %lld", totalOutputFrames_debug);
        outFilePacketOffset += ioOutDataPacketsPerOut;
    }
    
    NSLog(@"convert 结束");
    if (outBuffer) {
        free(outBuffer);
        outBuffer = NULL;
    }
    if(_inBuffer) {
        free(_inBuffer);
        _inBuffer = NULL;
    }
    if (_outPCMFile) {
        fclose(_outPCMFile);
        _outPCMFile = NULL;
    }
    
    JBAssertNoError( AudioConverterDispose(audioConverter),@"AudioConverterFillComplexBuffer");
    
    JBAssertNoError(AudioFileClose(_inFile), @"AudioFileClose in");
    JBAssertNoError(AudioFileClose(_outFile),@"AudioFileClose out");
    NSLog(@"所有结束\n");
    
    [JBHelper prisnFFmpegLogWithASBD:self.outASBD path:[outURL.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""] preLog:@"apple caf file:\t"];
    [JBHelper prisnFFmpegLogWithASBD:self.outASBD path:pathStr_cfile preLog:@"c write pcm file:\t"];
    
    self.isRunning = NO;
}

//填充了一个 16字节的 整型的，音频数据格式
- (void)fillUpOutASBDWithInputFile {
    AudioStreamBasicDescription asbd = {0};
    //mSampleRate 使用 输入文件的 的值
    asbd.mSampleRate = self.inASBD.mSampleRate;
    //输入固定为pcm文件
    asbd.mFormatID = kAudioFormatLinearPCM;
    //kAudioFormatFlagIsSignedInteger 还是 kAudioFormatFlagIsFloat 看自己输入而定
    asbd.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    
    //下面的数据都是计算得出
    asbd.mChannelsPerFrame = self.inASBD.mChannelsPerFrame;
    asbd.mBitsPerChannel = 16;
    asbd.mBytesPerFrame = (asbd.mBitsPerChannel >> 3) * asbd.mChannelsPerFrame;
    //pcm的一个包里面只有一个小样本帧
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerPacket = asbd.mFramesPerPacket * asbd.mBytesPerFrame;
    asbd.mReserved = self.inASBD.mReserved;
    
    self.outASBD = asbd;
    
    //TODO: 输出为 非 PCM的话，需要特殊处理
}


- (void)setInFileMetaDataToAudioConverter:(AudioConverterRef)converter {
    //先获取长度
    UInt32 cookieDataSize = 0;
    UInt32 isWriteAble = 0;
    //注意这里是AudioFileGetPropertyInfo， 获取长度和是否可以写
    OSStatus status = AudioFileGetPropertyInfo(_inFile, kAudioFilePropertyMagicCookieData, &cookieDataSize, &isWriteAble);
    
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
    JBAssertNoError(AudioFileGetProperty(_inFile, kAudioFilePropertyMagicCookieData, &cookieDataSize, cookieData),@"AudioFileGetProperty kAudioFilePropertyMagicCookieData");
    
    //将获取的MagicCookie 设置到 converter 中
    JBAssertNoError(AudioConverterSetProperty(converter,
                                              kAudioConverterDecompressionMagicCookie,
                                              cookieDataSize,
                                              cookieData),
                    @"AudioConverterSetProperty kAudioConverterDecompressionMagicCookie");
    
    // malloc 后必须 free
    free(cookieData);
}

static OSStatus JBAudioConverterCallback (AudioConverterRef               inAudioConverter,
                                          UInt32 *                        ioNumberDataPackets,
                                          AudioBufferList *               ioData,
                                          AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,
                                          void * __nullable               inUserData) {
    
    
    JBLicalAudioFileConvecter *jbClass = (__bridge JBLicalAudioFileConvecter *)inUserData;
    
    //不能超过我们开的的内存，的最大空间
    UInt32 maxPackets = jbClass.inNumPacketPerRead;
    if(*ioNumberDataPackets > maxPackets) {
        *ioNumberDataPackets = maxPackets;
    }

    if (*ioNumberDataPackets <= 0) {
        NSLog(@"*ioNumberDataPackets <= 0");
        //读完了，没有了
        return noErr;
    }

    
    //读取文件到 内存
    UInt32 outNumBytes = jbClass.inMaxSizePerPacket * (*ioNumberDataPackets); //这个值必须非0，根据最大包大小计算的值，读取的时候会改成实际值
    OSStatus status = AudioFileReadPacketData(jbClass->_inFile,
                                              false,
                                              &outNumBytes,
                                              jbClass.inASPDs,
                                              jbClass.inPacketReadIndex,
                                              ioNumberDataPackets,
                                              jbClass->_inBuffer);
    printErr(@"AudioFileReadPacketData", status);
    
    NSLog(@"io读取：%d", outNumBytes);
    if (eofErr == status) return noErr;
    
    jbClass.inPacketReadIndex += *ioNumberDataPackets;
    
    //将自己获取的到buffer，塞入 io队列中。
    ioData->mBuffers[0].mData = jbClass->_inBuffer;
    ioData->mBuffers[0].mDataByteSize = outNumBytes;
    ioData->mBuffers[0].mNumberChannels = jbClass.inASBD.mChannelsPerFrame;
    
    //aspd
    if (outDataPacketDescription) {
        *outDataPacketDescription = jbClass.inASPDs;
    }
    
    return noErr;
}

@end
