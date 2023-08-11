//
//  JBLocalAudioFileConvecter.m
//  CoreAudioDemo
//
//  Created by jimbo on 2023/7/21.
//

#import "JBLocalAudioFileConvecter.h"
#include "JBHelper.h"
#include <AudioToolbox/AudioToolbox.h>

@interface JBLocalAudioFileConvecter()
{
@public
    AudioFileID _inFile; //输入文件指针
    AudioFileID _outFile; //输出文件1 .caf 文件会在头部包含必要的asbd信息
    FILE *_outFile_2; //输出文件2 .pcm全是裸数据
    char * _inBuffer; //复用的输入缓冲区
}

@property (atomic, assign) BOOL isRunning; //代表是否正在编解码
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, strong) NSURL *inFileURL;
@property (nonatomic, strong) NSURL *outFileURL1; //输出文件 使用 AudioFileID
@property (nonatomic, strong) NSURL *outFileURL2; //输出文件 使用 FILE *

/**------   输入   ---------**/
@property (nonatomic, assign) AudioStreamBasicDescription inASBD;
@property (nonatomic, assign) UInt32 inMaxSizePerPacket; //输入文件包里面的最大尺寸的包的尺寸
@property (nonatomic, assign) UInt32 inNumPacketPerRead; //输入文件的，自己malloc的buffer内能容纳的最大packet数量
@property (nonatomic, assign) UInt32 inPacketReadIndex; //输入文件读取的包的下标
@property (nonatomic, assign) AudioStreamPacketDescription *inASPDs;

/**------   输出   ---------**/
@property (atomic, assign) AudioFormatID outputFormat; //输出文件格式，pcm? aac? flac? mp3?
@property (nonatomic, assign) AudioStreamBasicDescription outASBD;
@property (nonatomic, assign) AudioStreamPacketDescription *outASPDs;

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

@implementation JBLocalAudioFileConvecter
+ (instancetype)sharedInstance {
    static JBLocalAudioFileConvecter *sharedSingleton = nil;
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

- (void)setupStartData {
    self.isRunning = YES;
    self.inASPDs = NULL;
    self.outASPDs = NULL;
    self.inASPDs = NULL;
    _outFile_2 = NULL;
    _inBuffer = NULL;
    _inFile = NULL;
    _outFile = NULL;
    self.outputFormat = kAudioFormatLinearPCM;
    self.inPacketReadIndex = 0;
}

// 开始
- (void)start {
    [self startConvertFlac_to_pcm];
}

- (void)startConvertFlac_to_pcm {
    if (self.isRunning) {
        return;
    };
    [self setupStartData];
    dispatch_async(self.workQueue, ^{
        self.inFileURL  = [[NSBundle mainBundle] URLForResource:@"句号_10s" withExtension:@"flac"];
        self.outFileURL1 = [JBHelper getOutputPathWithFile:@"output.caf"]; //包含头信息
        self.outFileURL2 = [JBHelper getOutputPathWithFile:@"pcm_output.pcm"]; //纯裸数据
        self.outputFormat = kAudioFormatLinearPCM;
        [self workSubThread];
    });
}

- (void)startConvertPcm_to_flac {
    if (self.isRunning) {
        return;
    };
    [self setupStartData];
    dispatch_async(self.workQueue, ^{
        self.inFileURL  = [[NSBundle mainBundle] URLForResource:@"pcm_44100_setro_s16be" withExtension:@"caf"];
        self.outFileURL1 = [JBHelper getOutputPathWithFile:@"apple_out.flac"];
        self.outFileURL2 = [JBHelper getOutputPathWithFile:@"c_out.flac"];
        self.outputFormat = kAudioFormatFLAC; //可以改成其他类型，比如aac，MP3等
        
        [self workSubThread];
    });
}

- (void)stop {
    self.isRunning = NO;
}

- (void)workSubThread {
    //打开 输入 音频 文件
    JBAssertNoError(AudioFileOpenURL((__bridge  CFURLRef)self.inFileURL, kAudioFileReadPermission, 0, &_inFile), @"AudioFileOpenURL");
    
    //获取输入文件的 ASBD
    UInt32 size = sizeof(AudioStreamBasicDescription);
    JBAssertNoError(AudioFileGetProperty(_inFile, kAudioFilePropertyDataFormat, &size, &_inASBD), @"AudioFileGetProperty kAudioFilePropertyDataFormat");
    
    [self fillUpOutASBDWithInputFile];
    
    //打开 输出 音频 文件1
    JBAssertNoError(AudioFileCreateWithURL((__bridge CFURLRef)self.outFileURL1, kAudioFileCAFType, &_outASBD, kAudioFileFlags_EraseFile, &_outFile),@"AudioFileCreateWithURL");
    
    //打开 输出 音频 文件2
    if (_outFile_2 == NULL) {
        NSString *pathStr_cfile = [self.outFileURL2.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        _outFile_2 = fopen([pathStr_cfile UTF8String], "wb++");
    }

    //创建转换对象
    AudioConverterRef audioConverter;
    JBAssertNoError(AudioConverterNew(&_inASBD, &_outASBD, &audioConverter),@"AudioConverterNew");
    
    //读取magic cookie
    [self readMagicCookie:audioConverter];
    
    //重新从 Audio Convert 获取被校正过的 ASBD数据
    JBAssertNoError(AudioConverterGetProperty(audioConverter, kAudioConverterCurrentInputStreamDescription, &size, &_inASBD), @"kAudioConverterCurrentInputStreamDescription get infile");
    JBAssertNoError(AudioConverterGetProperty(audioConverter, kAudioConverterCurrentOutputStreamDescription, &size, &_outASBD), @"kAudioConverterCurrentInputStreamDescription get outfile");
    
    printf("\n\n    after inASBD\n");
    [JBHelper printASBD:self.inASBD];
    printf("\n\n    after outASBD\n");
    [JBHelper printASBD:self.outASBD];
    
    //设置输入缓冲区的数据大小
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
    
    /**  配置输出信息  */
    char *outBuffer;
    UInt32 outBufferSize = 4096*8; //输出缓冲区的大小，这里设置成和输入一样的值
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
    
    //写 magic cookie 到输出文件
    [self writeMagicCookie:audioConverter];
    
    if(self.inASBD.mChannelsPerFrame > 2) {
        //TODO: 多channel
        NSAssert(false, @"需要写入channel layout 到audio convert 中才能正常转换");
    }
    
    
    NSLog(@"---每次输入的包数量：numPaketPerOut: %d", numPaketPerOut);
    NSLog(@"---outSizePerPacket: %d", outSizePerPacket);
    NSLog(@"---outBufferSize: %d", outBufferSize);
    
    UInt64 totalOutputFrames_debug = 0;
    UInt32 outFilePacketOffset = 0; //输出文件的写入偏移量
    
    OSStatus status = noErr;
    //阻塞式
    while (true) {
        if (!_isRunning) {
            break;
        }
        
        //创建输出的AudioBuffer
        AudioBufferList outBufferList = {0};
        outBufferList.mNumberBuffers = 1;
        outBufferList.mBuffers[0].mNumberChannels = self.outASBD.mChannelsPerFrame;
        outBufferList.mBuffers[0].mDataByteSize = outBufferSize;
        outBufferList.mBuffers[0].mData = outBuffer; //这里直接将我们上面malloc的对象赋值进去，每次重用堆空间
        
        //malloc的输入缓冲区能够装下的最大包数量
        UInt32 ioOutDataPacketsPerOut = numPaketPerOut;
        status = AudioConverterFillComplexBuffer(audioConverter,
                                                          JBAudioConverterCallback,
                                                          (__bridge void *)self,
                                                          &ioOutDataPacketsPerOut, //输出的数量
                                                          &outBufferList, //输出的buffer
                                                          self.outASPDs //输出文件的aspd，我们在上面开辟了内存
                                                 );
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
        
        //写入文件 到 AudioFile
        JBAssertNoError(AudioFileWritePackets(_outFile,
                                              false,
                                              outBufferList.mBuffers[0].mDataByteSize,
                                              self.outASPDs,
                                              outFilePacketOffset,
                                              &ioOutDataPacketsPerOut,
                                              outBuffer),
                        @"AudioFileWritePackets");
        
        //写入文件到FILE *
        fwrite((char *)outBufferList.mBuffers[0].mData, sizeof(char), outBufferList.mBuffers[0].mDataByteSize, _outFile_2);
        
        //debug 统计
        if (self.outASBD.mBytesPerPacket > 0) {
            totalOutputFrames_debug += (ioOutDataPacketsPerOut * self.outASBD.mFramesPerPacket);
        } else if (self.outASPDs) {
            for(UInt32 i= 0; i < ioOutDataPacketsPerOut; i++) {
                totalOutputFrames_debug += self.outASPDs[i].mVariableFramesInPacket;
            }
        }
        
        //下次输出文件的时候，需要增加这次输出的数量
        outFilePacketOffset += ioOutDataPacketsPerOut;
    } //end while
    
    if (status == noErr) {
        if (self.outASBD.mBitsPerChannel == 0) {
            NSLog(@"总共写入frame数量: %lld", totalOutputFrames_debug);
            [self writePacketTableInfo_inTrailer:audioConverter];
        }
        
        //在写一次cookie，有时编解码器会在转换结束时更新 cookie
        [self writeMagicCookie:audioConverter];
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
    if (_outFile_2) {
        fclose(_outFile_2);
        _outFile_2 = NULL;
    }
    //关闭和释放AudioConverter的资源
    JBAssertNoError( AudioConverterDispose(audioConverter),@"AudioConverterFillComplexBuffer");
    if (_inFile) {
        JBAssertNoError(AudioFileClose(_inFile), @"AudioFileClose in");
        _inFile = NULL;
    }
    if (_outFile) {
        JBAssertNoError(AudioFileClose(_outFile),@"AudioFileClose out");
        _outFile = NULL;
    }
    NSLog(@"所有结束\n");
    
    [JBHelper prisnFFmpegLogWithASBD:self.outASBD path:[self.outFileURL1.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""] preLog:@"apple caf file:\t"];
    [JBHelper prisnFFmpegLogWithASBD:self.outASBD path:[self.outFileURL2.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""] preLog:@"c write pcm file:\t"];
    
    self.isRunning = NO;
}

//填充了一个 16字节的 整型的，音频数据格式
- (void)fillUpOutASBDWithInputFile {
    AudioStreamBasicDescription asbd = {0};
    //mSampleRate 使用 输入文件的 的值
    asbd.mSampleRate = self.inASBD.mSampleRate;
    //输入固定为pcm文件
    asbd.mFormatID = self.outputFormat;
    
    if (asbd.mFormatID == kAudioFormatLinearPCM) {
        //kAudioFormatFlagIsSignedInteger 还是 kAudioFormatFlagIsFloat 看自己输入而定
        //大端，小端，根据自己情况而定
        asbd.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        
        //下面的数据都是计算得出
        asbd.mChannelsPerFrame = self.inASBD.mChannelsPerFrame;
        asbd.mBitsPerChannel = 16;
        asbd.mBytesPerFrame = (asbd.mBitsPerChannel >> 3) * asbd.mChannelsPerFrame;
        //pcm的一个包里面只有一个小样本帧
        asbd.mFramesPerPacket = 1;
        asbd.mBytesPerPacket = asbd.mFramesPerPacket * asbd.mBytesPerFrame;
        asbd.mReserved = self.inASBD.mReserved;
    } else {
        //非pcm的话，其他参数可能设置不正确，需要调用api来自动赋值。
        asbd.mChannelsPerFrame = (asbd.mFormatID == kAudioFormatiLBC ? 1 : self.inASBD.mChannelsPerFrame);
        
        UInt32 size = sizeof(asbd);
        //使用format api 自动填充对应的参数数据
        JBAssertNoError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &asbd), @"AudioFormatGetProperty kAudioFormatProperty_FormatInfo");
    }
    
    self.outASBD = asbd;
}

- (void)readMagicCookie:(AudioConverterRef)converter {
    //先获取长度
    UInt32 cookieDataSize = 0;
    UInt32 isWriteAble = 0;
    //注意这里是AudioFileGetPropertyInfo， 获取长度和是否可以写
    OSStatus status = AudioFileGetPropertyInfo(_inFile, kAudioFilePropertyMagicCookieData, &cookieDataSize, &isWriteAble);
    
    //有些没有 magic cookie ，所以不管
    if (status != noErr) {
        NSLog(@"读取 magic cookie 不存在，忽略掉");
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

- (void)writeMagicCookie:(AudioConverterRef)converter {
    
    UInt32 cookieDataSize = 0;
    OSStatus status = AudioConverterGetPropertyInfo(converter, kAudioConverterCompressionMagicCookie, &cookieDataSize, NULL);
    if (status != noErr && cookieDataSize == 0) {
        NSLog(@"写入 magic cookie 不存在，忽略掉");
        return;
    }
    
    void *cookies = malloc(cookieDataSize);
    status = AudioConverterGetProperty(converter, kAudioConverterDecompressionMagicCookie, &cookieDataSize, cookies);
    if (status == noErr) {
        status = AudioFileSetProperty(_outFile, kAudioFilePropertyMagicCookieData, cookieDataSize, cookies);
        printErr(@"AudioFileSetProperty kAudioFilePropertyMagicCookieData", status);
    } else {
        NSLog(@"magic cookie 是空的，忽略");
    }
    
    free(cookies);
}
static OSStatus JBAudioConverterCallback (AudioConverterRef               inAudioConverter,
                                          UInt32 *                        ioNumberDataPackets,
                                          AudioBufferList *               ioData,
                                          AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,
                                          void * __nullable               inUserData) {
    
    
    JBLocalAudioFileConvecter *jbClass = (__bridge JBLocalAudioFileConvecter *)inUserData;
    
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

/**
 kAudioConverterPrimeInfo：AudioConverter的启动信息。一些音频数据格式转换，特别是那些涉及采样率转换的音频数据格式转换，
 当有leadingFrames或trailingFrames可用时，会产生更高质量的输出。 这些启动信息的适当数量取决于输入的音频数据格式。
 */
- (void)writePacketTableInfo_inTrailer:(AudioConverterRef)converter {
    /**
     mNumberPackets是包含在文件中的音频数据的总的分组数；
     mPrimingFrames是经过分组(“packetized”)的流用作准备和/或处理等待时间的帧数；
     mRemainderFrames是最后分组遗留下的帧数。例如，AAC位流可能仅有在其最后分组中有效的313帧。每分组的帧为1024，所以，在此情形，mRemainderFrames是(1024-313)，其表示了当进行解码时应该从最后分组的输出中裁剪下来的样本数。
     如果经过编码的位流正被编辑，那么就推荐在将会占据至少mPrimingFrames的编辑点之前的分组应该被所述编辑所采用，以从编辑点中确保音频的完美再现。当然，在随机访问文件中的不同分组以便播放时，mPrimingFrames就应该被用来在所想要的点上重新构造音频。
     */
    UInt32 size = 0;
    UInt32 isWritable;
    OSStatus status = AudioFileGetPropertyInfo(_outFile, kAudioFilePropertyPacketTableInfo, &size, &isWritable);
    printErr(@"AudioFileGetPropertyInfo kAudioFilePropertyPacketTableInfo", status);
    
    if (noErr != status || isWritable == 0) {
        NSLog(@"AudioFileGetPropertyInfo kAudioFilePropertyPacketTableInfo failed return");
        return;
    }
    /**
     UInt32      leadingFrames;  ->  0
     UInt32      trailingFrames; -> 1368
     */
    AudioConverterPrimeInfo primeInfo;
    size = sizeof(primeInfo);
    status = AudioConverterGetProperty(converter, kAudioConverterPrimeInfo, &size, &primeInfo);
    printErr(@"AudioConverterGetProperty kAudioConverterPrimeInfo", status);
    if (status !=noErr) return;
    
    /**
     SInt64  mNumberValidFrames;  ->  442368
     SInt32  mPrimingFrames;      ->  0
     SInt32  mRemainderFrames;    ->  0
     */
    AudioFilePacketTableInfo pTableInfo;
    size = sizeof(pTableInfo);
    
    status = AudioFileGetProperty(_outFile, kAudioFilePropertyPacketTableInfo, &size, &pTableInfo);
    printErr(@"AudioFileGetProperty kAudioFilePropertyPacketTableInfo", status);
    if (status !=noErr) return;
    
    //获取总数量的帧数
    UInt64 totalFrames = pTableInfo.mNumberValidFrames + pTableInfo.mPrimingFrames + pTableInfo.mRemainderFrames;
    
    
    pTableInfo.mPrimingFrames = primeInfo.leadingFrames;
    pTableInfo.mRemainderFrames = primeInfo.trailingFrames;
    pTableInfo.mNumberValidFrames = totalFrames - pTableInfo.mPrimingFrames - pTableInfo.mRemainderFrames;
    
    NSLog(@"table info 里面包含的总数量的帧数: %llu,\t mNumberValidFrames:%lld,\t mPrimingFrames：%d,\t mRemainderFrames:%d", totalFrames, pTableInfo.mNumberValidFrames, pTableInfo.mPrimingFrames, pTableInfo.mRemainderFrames);
    
    /**
     SInt64  mNumberValidFrames;  ->  441100
     SInt32  mPrimingFrames;      ->  0
     SInt32  mRemainderFrames;    ->  1368   (1368 不够组成一个 flac packet，所以被遗留下来？)
     */
    status = AudioFileSetProperty(_outFile, kAudioFilePropertyPacketTableInfo, sizeof(pTableInfo), &pTableInfo);
    printErr(@"AudioFileSetProperty kAudioFilePropertyPacketTableInfo", status);
}

@end
