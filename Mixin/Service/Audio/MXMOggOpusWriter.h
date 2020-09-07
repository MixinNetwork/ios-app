#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(OggOpusWriter)
@interface MXMOggOpusWriter : NSObject

+ (instancetype)writerWithPath:(NSString *)path
               inputSampleRate:(int32_t)inputSampleRate
                         error:(NSError * _Nullable *)outError;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithPath:(NSString *)path
                      inputSampleRate:(int32_t)inputSampleRate
                                error:(NSError * _Nullable *)outError;
- (void)close;
- (void)removeFile;
- (void)writePCMData:(NSData *)pcmData;

@end

NS_ASSUME_NONNULL_END
