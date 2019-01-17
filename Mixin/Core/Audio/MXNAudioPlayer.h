
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN const NSErrorDomain MXNAudioPlayerErrorDomain;

typedef NS_ENUM(NSUInteger, MXNAudioPlayerErrorCode) {
    MXNAudioPlayerErrorCodeNewOutput,
    MXNAudioPlayerErrorCodeAllocateBuffers,
    MXNAudioPlayerErrorCodeAddPropertyListener,
    MXNAudioPlayerErrorCodeStop,
    MXNAudioPlayerErrorCodeCancelled
};

@interface MXNAudioPlayer : NSObject

@property (nonatomic, assign, readonly) BOOL isPlaying;
@property (nonatomic, assign, readonly) Float64 currentTime;
@property (nonatomic, copy, readonly) NSString *path;

+ (instancetype)sharedPlayer;

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError * _Nullable *)outError;
- (void)play;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
