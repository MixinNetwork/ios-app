
#import <Foundation/Foundation.h>
#import "MXNAudioMetadata.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN const NSErrorDomain MXNAudioRecorderErrorDomain;

typedef NS_CLOSED_ENUM(NSUInteger, MXNAudioRecorderErrorCode) {
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


@class MXNAudioRecorder;

@protocol MXNAudioRecorderDelegate <NSObject>

- (void)audioRecorderIsWaitingForActivation:(MXNAudioRecorder *)recorder NS_SWIFT_NAME(audioRecorderIsWaitingForActivation(_:));
- (void)audioRecorderDidStartRecording:(MXNAudioRecorder *)recorder;
- (void)audioRecorderDidCancelRecording:(MXNAudioRecorder *)recorder;
- (void)audioRecorder:(MXNAudioRecorder *)recorder didFailRecordingWithError:(NSError *)error;
- (void)audioRecorder:(MXNAudioRecorder *)recorder didFinishRecordingWithMetadata:(MXNAudioMetadata *)data NS_SWIFT_NAME(audioRecorder(_:didFinishRecordingWithMetadata:));

@end


@interface MXNAudioRecorder : NSObject

@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, assign, readwrite) BOOL vibratesAtBeginning;
@property (nonatomic, assign, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, weak, readwrite) id<MXNAudioRecorderDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithPath:(NSString *)path error:(NSError * _Nullable *)outError;
- (void)recordForDuration:(NSTimeInterval)duration NS_SWIFT_NAME(record(for:));
- (void)stop;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
