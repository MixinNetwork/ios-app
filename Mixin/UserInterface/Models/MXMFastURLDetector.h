#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(FastURLDetector)
@interface MXMFastURLDetector : NSObject

- (void)enumerateMatchesInString:(NSString *)string options:(NSMatchingOptions)options usingBlock:(void (NS_NOESCAPE ^)(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL *stop))block;

@end

NS_ASSUME_NONNULL_END
