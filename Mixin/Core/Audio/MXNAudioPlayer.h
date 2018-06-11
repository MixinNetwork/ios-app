
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MXNAudioPlayer;

typedef NS_ENUM(NSUInteger, MXNAudioPlaybackState) {
    MXNAudioPlaybackStatePreparing,
    MXNAudioPlaybackStateReadyToPlay,
    MXNAudioPlaybackStatePlaying,
    MXNAudioPlaybackStatePaused,
    MXNAudioPlaybackStateStopped,
    MXNAudioPlaybackStateDisposed
};

FOUNDATION_EXTERN NSString* NSStringFromMXNAudioPlaybackState(MXNAudioPlaybackState state);

@protocol MXNAudioPlayerObserver

- (void)mxnAudioPlayer:(MXNAudioPlayer *)player playbackStateDidChangeTo:(MXNAudioPlaybackState)state;

@end

FOUNDATION_EXTERN const NSErrorDomain MXNAudioPlayerErrorDomain;

typedef NS_ENUM(NSUInteger, MXNAudioPlayerErrorCode) {
    MXNAudioPlayerErrorCodeNewOutput,
    MXNAudioPlayerErrorCodeAllocateBuffers,
    MXNAudioPlayerErrorCodeAddPropertyListener,
    MXNAudioPlayerErrorCodeStop,
    MXNAudioPlayerErrorCodeCancelled
};

typedef void (^MXNAudioPlayerLoadFileCompletionCallback)(BOOL success, NSError* _Nullable error);

@interface MXNAudioPlayer : NSObject

@property (nonatomic, assign, readonly) MXNAudioPlaybackState state;
@property (nonatomic, assign, readonly) Float64 currentTime;
@property (nonatomic, copy, readonly) NSString *path;

+ (instancetype)sharedPlayer;

- (void)playFileAtPath:(NSString *)path completion:(MXNAudioPlayerLoadFileCompletionCallback)completion;
- (void)play;
- (void)pause;
- (void)stopWithAudioSessionDeactivated:(BOOL)shouldDeactivate;
- (void)addObserver:(id<MXNAudioPlayerObserver>)observer NS_SWIFT_NAME(addObserver(_:));
- (void)removeObserver:(id<MXNAudioPlayerObserver>)observer NS_SWIFT_NAME(removeObserver(_:));

@end

NS_ASSUME_NONNULL_END
