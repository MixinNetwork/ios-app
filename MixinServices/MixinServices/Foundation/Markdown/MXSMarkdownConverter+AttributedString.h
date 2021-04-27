#import <Foundation/Foundation.h>
#import "MXSMarkdownConverter.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXSMarkdownConverter (AttributedString)

+ (NSUInteger)unlimitedNumber;
+ (NSAttributedString *)attributedStringFromMarkdownString:(NSString *)markdownString
                                     maxNumberOfCharacters:(NSUInteger)maxNumberOfCharacters
                                          maxNumberOfLines:(NSUInteger)maxNumberOfLines
NS_SWIFT_NAME(attributedString(from:maxNumberOfCharacters:maxNumberOfLines:));

@end

NS_ASSUME_NONNULL_END
