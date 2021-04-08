#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(MarkdownConverter)
@interface MXSMarkdownConverter : NSObject

+ (NSString *)plainTextFromMarkdownString:(NSString *)markdownString
NS_SWIFT_NAME(plainText(from:));

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
