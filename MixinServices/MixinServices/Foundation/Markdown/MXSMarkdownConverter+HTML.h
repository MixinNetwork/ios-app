#import <Foundation/Foundation.h>
#import "MXSMarkdownConverter.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXSMarkdownConverter (HTML)

+ (NSString *)htmlStringFromMarkdownString:(NSString *)markdownString
                                richFormat:(BOOL)rich
NS_SWIFT_NAME(htmlString(from:richFormat:));

@end

NS_ASSUME_NONNULL_END
