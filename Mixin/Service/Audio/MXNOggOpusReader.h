
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MXNOggOpusReader : NSObject

@property (nonatomic, assign, readonly) BOOL hasDataAvailable;

+ (nullable instancetype)readerWithFileAtPath:(NSString *)path error:(NSError * _Nullable *)outError;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithFileAtPath:(NSString *)path error:(NSError * _Nullable *)outError;
- (NSData * _Nullable)pcmDataWithMaxLength:(NSUInteger)maxLength error:(NSError * _Nullable *)outError;
- (void)seekToZero;
- (void)close;

@end

NS_ASSUME_NONNULL_END
