
#import <Foundation/Foundation.h>
#import "MXNAudioMetadata.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MXNAudioRecorderProgress) {
    MXNAudioRecorderProgressWaitingForActivation,
    MXNAudioRecorderProgressStarted,
    MXNAudioRecorderProgressInterrupted
};

typedef NS_ENUM(NSUInteger, MXNAudioRecorderCompletion) {
    MXNAudioRecorderCompletionFailed,
    MXNAudioRecorderCompletionFinished,
    MXNAudioRecorderCompletionCancelled
};

FOUNDATION_EXTERN const NSErrorDomain MXNAudioRecorderErrorDomain;

typedef NS_ENUM(NSUInteger, MXNAudioRecorderErrorCode) {
    MXNAudioRecorderErrorCodeAudioQueueNewInput,
    MXNAudioRecorderErrorCodeAudioQueueGetStreamDescription,
    MXNAudioRecorderErrorCodeAudioQueueAllocateBuffer,
    MXNAudioRecorderErrorCodeAudioQueueEnqueueBuffer,
    MXNAudioRecorderErrorCodeAudioQueueStart,
    MXNAudioRecorderErrorCodeAudioQueueGetMaximumOutputPacketSize,
    MXNAudioRecorderErrorCodeCreateAudioFile,
    MXNAudioRecorderErrorCodeWriteAudioFile,
    MXNAudioRecorderErrorCodeMediaServiceWereReset
};

typedef void (^MXNAudioRecorderProgressCallback)(MXNAudioRecorderProgress progress);
typedef void (^MXNAudioRecorderCompletionCallback)(MXNAudioRecorderCompletion completion, MXNAudioMetadata* _Nullable metadata, NSError* _Nullable error);

@interface MXNAudioRecorder : NSObject

@property (nonatomic, assign, readwrite) BOOL vibratesAtBeginning;
@property (nonatomic, assign, readonly, getter=isRecording) BOOL recording;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithPath:(NSString *)path error:(NSError * _Nullable *)outError;
- (void)recordForDuration:(NSTimeInterval)duration
                 progress:(MXNAudioRecorderProgressCallback)progress
               completion:(MXNAudioRecorderCompletionCallback)completion;
- (void)stop;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
