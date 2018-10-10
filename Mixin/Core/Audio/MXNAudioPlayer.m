
#import "MXNAudioPlayer.h"
#import "MXNOggOpusReader.h"
#import <AVFoundation/AVFoundation.h>

const NSErrorDomain MXNAudioPlayerErrorDomain = @"MXNAudioRecorderErrorDomain";

static const Float64 sampleRate = 48000;
static const int numberOfAudioQueueBuffers = 3;
static const UInt32 audioQueueBufferSize = 65536; // Should be smaller than UINT32_MAX (type of AudioQueueBufferRef.mAudioDataByteSize)

NS_INLINE NSError* ErrorWithCodeAndOSStatus(MXNAudioPlayerErrorCode code, OSStatus status);
NS_INLINE AudioStreamBasicDescription CreateFormat(void);

@implementation MXNAudioPlayer {
    dispatch_queue_t _processingQueue;
    AudioQueueRef _audioQueue;
    AudioQueueBufferRef _buffers[numberOfAudioQueueBuffers];
    AudioQueueTimelineRef _timeline;
    MXNOggOpusReader *_reader;
    NSHashTable<id<MXNAudioPlayerObserver>> *_observers;
}

+ (instancetype)sharedPlayer {
    static MXNAudioPlayer *sharedPlayer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlayer = [[MXNAudioPlayer alloc] init];
    });
    return sharedPlayer;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _processingQueue = dispatch_queue_create("one.mixin.queue.audio_player", DISPATCH_QUEUE_SERIAL);
        _audioQueue = NULL;
        _observers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
        _state = MXNAudioPlaybackStatePreparing;
    }
    return self;
}

- (Float64)currentTime {
    if (_state != MXNAudioPlaybackStatePlaying) {
        return 0;
    }
    AudioTimeStamp timeStamp;
    AudioQueueGetCurrentTime(_audioQueue, _timeline, &timeStamp, NULL);
    return timeStamp.mSampleTime / sampleRate;
}

- (void)playFileAtPath:(NSString *)path completion:(MXNAudioPlayerLoadFileCompletionCallback)completion {
    if ([path isEqualToString:_path]) {
        switch (_state) {
            case MXNAudioPlaybackStatePreparing: {
                // Not expected to happend
                return;
            }
            case MXNAudioPlaybackStateReadyToPlay:
            case MXNAudioPlaybackStatePlaying:
            case MXNAudioPlaybackStatePaused:
            case MXNAudioPlaybackStateStopped: {
                [self play];
                completion(YES, nil);
                return;
            }
            case MXNAudioPlaybackStateDisposed: {
                break;
            }
        }
    } else {
        [self stopWithAudioSessionDeactivated:NO];
        [self dispose];
        _path = path;
    }
    dispatch_async(_processingQueue, ^{
        NSError *error = nil;

        if (_path != path) {
            error = [NSError errorWithDomain:MXNAudioPlayerErrorDomain
                                        code:MXNAudioPlayerErrorCodeCancelled
                                    userInfo:nil];
            completion(NO, error);
            return;
        }
        
        [self setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStatePreparing];
        
        MXNOggOpusReader *reader = [MXNOggOpusReader readerWithFileAtPath:path error:&error];
        if (!reader) {
            completion(NO, error);
            return;
        }

        self->_reader = reader;
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        BOOL success = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                       mode:AVAudioSessionModeDefault
                                    options:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth
                                      error:&error];
        if (!success) {
            [self dispose];
            completion(NO, error);
            return;
        }
        
        success = [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (!success) {
            [self dispose];
            completion(NO, error);
            return;
        }
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self
                   selector:@selector(audioSessionInterruption:)
                       name:AVAudioSessionInterruptionNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(audioSessionRouteChange:)
                       name:AVAudioSessionRouteChangeNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(audioSessionMediaServicesWereReset:)
                       name:AVAudioSessionMediaServicesWereResetNotification
                     object:nil];
        
        AudioStreamBasicDescription format = CreateFormat();
        OSStatus result;
        result = AudioQueueNewOutput(&format, AQBufferCallback, (__bridge void *)(self), NULL, NULL, 0, &self->_audioQueue);
        if (result != noErr) {
            error = ErrorWithCodeAndOSStatus(MXNAudioPlayerErrorCodeNewOutput, result);
            [self dispose];
            completion(NO, error);
            return;
        }
        
        for (int i = 0; i < numberOfAudioQueueBuffers; ++i) {
            result = AudioQueueAllocateBuffer(self->_audioQueue, audioQueueBufferSize, &self->_buffers[i]);
            if (result != noErr) {
                error = ErrorWithCodeAndOSStatus(MXNAudioPlayerErrorCodeNewOutput, result);
                [self dispose];
                completion(NO, error);
                return;
            }
            AQBufferCallback((__bridge void *)(self), self->_audioQueue, self->_buffers[i]);
        }
        
        result = AudioQueueAddPropertyListener(self->_audioQueue, kAudioQueueProperty_IsRunning, isRunningChanged, (__bridge void * _Nullable)(self));
        if (result != noErr) {
            error = ErrorWithCodeAndOSStatus(MXNAudioPlayerErrorCodeAddPropertyListener, result);
            [self dispose];
            completion(NO, error);
        }
        
        AudioQueueCreateTimeline(self->_audioQueue, &self->_timeline);
        
        AudioQueueSetParameter(self->_audioQueue, kAudioQueueParam_Volume, 1.0);
        
        [self setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStateReadyToPlay];
        [self play];
        completion(YES, nil);
    });
}

- (void)play {
    if (_state == MXNAudioPlaybackStateStopped) {
        [self setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStatePreparing];
        [_reader seekToZero];
        for (int i = 0; i < numberOfAudioQueueBuffers; i++) {
            AQBufferCallback((__bridge void *)(self), self->_audioQueue, self->_buffers[i]);
        }
        [self setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStateReadyToPlay];
    }
    if (_state == MXNAudioPlaybackStateStopped || _state == MXNAudioPlaybackStateReadyToPlay || _state == MXNAudioPlaybackStatePaused) {
        AudioQueueStart(_audioQueue, NULL);
        [self setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStatePlaying];
    }
}

- (void)pause {
    if (_state != MXNAudioPlaybackStatePlaying) {
        return;
    }
    AudioQueuePause(_audioQueue);
    [self setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStatePaused];
}

- (void)stopWithAudioSessionDeactivated:(BOOL)shouldDeactivate {
    if (_state == MXNAudioPlaybackStateStopped || _state == MXNAudioPlaybackStateDisposed) {
        return;
    }
    [self setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStateStopped];
    AudioQueueStop(_audioQueue, TRUE);
    if (shouldDeactivate) {
        dispatch_async(_processingQueue, ^{
            BOOL shouldDeactivate = self->_state == MXNAudioPlaybackStateStopped || self->_state == MXNAudioPlaybackStateDisposed;
            if (shouldDeactivate) {
                AudioQueueStop(self->_audioQueue, TRUE);
                [[AVAudioSession sharedInstance] setActive:NO
                                               withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                                     error:nil];
            }
        });
    }
}

- (void)dispose {
    if (_state != MXNAudioPlaybackStateStopped) {
        [self stopWithAudioSessionDeactivated:YES];
    }
    if (_timeline) {
        AudioQueueDisposeTimeline(_audioQueue, _timeline);
        _timeline = nil;
    }
    if (_audioQueue) {
        AudioQueueDispose(_audioQueue, TRUE);
        _audioQueue = nil;
    }
    if (_reader) {
        [_reader close];
        _reader = nil;
    }
    [self setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStateDisposed];
}

- (void)addObserver:(id<MXNAudioPlayerObserver>)observer {
    [_observers addObject:observer];
}

- (void)removeObserver:(id<MXNAudioPlayerObserver>)observer {
    [_observers removeObject:observer];
}

- (void)setPlaybackStateAndNotifyObservers:(MXNAudioPlaybackState)state {
    _state = state;
    NSArray *observers = _observers.allObjects;
    for (id<MXNAudioPlayerObserver> observer in observers) {
        [observer mxnAudioPlayer:self playbackStateDidChangeTo:state];
    }
}

- (void)audioSessionInterruption:(NSNotification *)notification {
    [self stopWithAudioSessionDeactivated:YES];
}

- (void)audioSessionRouteChange:(NSNotification *)notification {
    AVAudioSessionRouteChangeReason reason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonOverride:
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
        case AVAudioSessionRouteChangeReasonRouteConfigurationChange: {
            break;
        }
        case AVAudioSessionRouteChangeReasonCategoryChange: {
            NSString *newCategory = [[AVAudioSession sharedInstance] category];
            BOOL canContinue = [newCategory isEqualToString:AVAudioSessionCategoryRecord] || [newCategory isEqualToString:AVAudioSessionCategoryPlayAndRecord];
            if (!canContinue) {
                [self stopWithAudioSessionDeactivated:YES];
            }
            break;
        }
        case AVAudioSessionRouteChangeReasonUnknown:
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory: {
            [self stopWithAudioSessionDeactivated:YES];
            break;
        }
    }
}

- (void)audioSessionMediaServicesWereReset:(NSNotification *)notification {
    _audioQueue = nil;
    if (_reader) {
        [_reader close];
        _reader = nil;
    }
    [self setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStateDisposed];
}

void AQBufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    MXNAudioPlayer *player = (__bridge MXNAudioPlayer *)inUserData;
    if (player->_state == MXNAudioPlaybackStateStopped || player->_state == MXNAudioPlaybackStateDisposed) {
        return;
    }
    NSData *pcmData = [player->_reader pcmDataWithMaxLength:audioQueueBufferSize error:nil];
    NSCAssert(pcmData.length <= audioQueueBufferSize,  @"Too many PCM data");
    if (pcmData && pcmData.length > 0) {
        inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
        [pcmData getBytes:inBuffer->mAudioData length:pcmData.length];
        AudioQueueEnqueueBuffer(player->_audioQueue, inBuffer, 0, NULL);
    } else {
        if (player->_state == MXNAudioPlaybackStatePlaying) {
            [player stopWithAudioSessionDeactivated:YES];
        }
    }
}

void isRunningChanged(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    MXNAudioPlayer *player = (__bridge MXNAudioPlayer*)inUserData;
    UInt32 isRunning;
    UInt32 size = sizeof(isRunning);
    OSStatus result = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size);
    if (result == noErr && !isRunning && player->_state != MXNAudioPlaybackStateStopped) {
        NSLog(@"isRunningChanged post stoped. previous: %@", NSStringFromMXNAudioPlaybackState(player->_state));
        [player setPlaybackStateAndNotifyObservers:MXNAudioPlaybackStateStopped];
    }
}

@end

NS_INLINE NSError* ErrorWithCodeAndOSStatus(MXNAudioPlayerErrorCode code, OSStatus status) {
    NSDictionary *userInfo = @{@"os_status" : @(status)};
    return [NSError errorWithDomain:MXNAudioPlayerErrorDomain
                               code:code
                           userInfo:userInfo];
}

NS_INLINE AudioStreamBasicDescription CreateFormat(void) {
    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    format.mSampleRate = sampleRate;
    format.mChannelsPerFrame = 1;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mBitsPerChannel = 16;
    format.mBytesPerPacket = format.mBytesPerFrame = (format.mBitsPerChannel / 8) * format.mChannelsPerFrame;
    format.mFramesPerPacket = 1;
    return format;
}

NSString* NSStringFromMXNAudioPlaybackState(MXNAudioPlaybackState state) {
    switch (state) {
        case MXNAudioPlaybackStatePreparing:
            return @"Preparing";
        case MXNAudioPlaybackStateReadyToPlay:
            return @"ReadyToPlay";
        case MXNAudioPlaybackStatePlaying:
            return @"Playing";
        case MXNAudioPlaybackStatePaused:
            return @"Paused";
        case MXNAudioPlaybackStateStopped:
            return @"Stopped";
        case MXNAudioPlaybackStateDisposed:
            return @"Disposed";
    }
}
