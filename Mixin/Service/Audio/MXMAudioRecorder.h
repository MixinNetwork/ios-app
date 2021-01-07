#import <Foundation/Foundation.h>
#import "MXMAudioMetadata.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN const NSErrorDomain MXMAudioRecorderErrorDomain;

typedef NS_CLOSED_ENUM(NSUInteger, MXMAudioRecorderErrorCode) {
    MXMAudioRecorderErrorCodeAudioQueueNewInput,
    MXMAudioRecorderErrorCodeAudioQueueGetStreamDescription,
    MXMAudioRecorderErrorCodeAudioQueueAllocateBuffer,
    MXMAudioRecorderErrorCodeAudioQueueEnqueueBuffer,
    MXMAudioRecorderErrorCodeAudioQueueStart,
    MXMAudioRecorderErrorCodeAudioQueueGetMaximumOutputPacketSize,
    MXMAudioRecorderErrorCodeCreateAudioFile,
    MXMAudioRecorderErrorCodeWriteAudioFile,
    MXMAudioRecorderErrorCodeMediaServiceWereReset
} NS_SWIFT_NAME(AudioRecorderErrorCode);

typedef NS_CLOSED_ENUM(NSUInteger, MXMAudioRecorderCancelledReason) {
    MXMAudioRecorderCancelledReasonAudioSessionInterrupted,
    MXMAudioRecorderCancelledReasonAudioRouteChange,
    MXMAudioRecorderCancelledReasonBufferEnqueueFailed,
    MXMAudioRecorderCancelledReasonUserInitiated,
} NS_SWIFT_NAME(AudioRecorderCancelledReason);

@class MXMAudioRecorder;

NS_SWIFT_NAME(AudioRecorderDelegate)
@protocol MXMAudioRecorderDelegate <NSObject>

- (void)audioRecorderIsWaitingForActivation:(MXMAudioRecorder *)recorder NS_SWIFT_NAME(audioRecorderIsWaitingForActivation(_:));
- (void)audioRecorderDidStartRecording:(MXMAudioRecorder *)recorder;
- (void)audioRecorderDidCancelRecording:(MXMAudioRecorder *)recorder
                              forReason:(MXMAudioRecorderCancelledReason)reason
                               userInfo:(NSDictionary<NSString*, id> * _Nullable)userInfo;
- (void)audioRecorder:(MXMAudioRecorder *)recorder didFailRecordingWithError:(NSError *)error;
- (void)audioRecorder:(MXMAudioRecorder *)recorder didFinishRecordingWithMetadata:(MXMAudioMetadata *)data NS_SWIFT_NAME(audioRecorder(_:didFinishRecordingWithMetadata:));

@end


NS_SWIFT_NAME(AudioRecorder)
@interface MXMAudioRecorder : NSObject

@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, assign, readwrite) BOOL vibratesAtBeginning;
@property (nonatomic, assign, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, weak, readwrite) id<MXMAudioRecorderDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithPath:(NSString *)path error:(NSError * _Nullable *)outError;
- (void)recordForDuration:(NSTimeInterval)duration NS_SWIFT_NAME(record(for:));
- (void)stop;
- (void)cancelForReason:(MXMAudioRecorderCancelledReason)reason
               userInfo:(NSDictionary<NSString*, id> * _Nullable)userInfo;

@end

NS_ASSUME_NONNULL_END
