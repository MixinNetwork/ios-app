#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(MarkdownConverter)
@interface MXMMarkdownConverter : NSObject

+ (NSString *)htmlStringFromMarkdownString:(NSString *)markdownString NS_SWIFT_NAME(htmlString(from:));

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
