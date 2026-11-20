#import <Foundation/Foundation.h>
#import "MXSMarkdownConverter.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXSMarkdownConverter (AttributedString)

+ (NSUInteger)unlimitedNumber;
+ (NSAttributedString *)attributedStringFromMarkdownString:(NSString *)markdownString
                                     maxNumberOfCharacters:(NSUInteger)maxNumberOfCharacters
                                          maxNumberOfLines:(NSUInteger)maxNumberOfLines
                                   continuesAfterFirstImage:(BOOL)continuesAfterFirstImage
NS_SWIFT_NAME(attributedString(from:maxNumberOfCharacters:maxNumberOfLines:continuesAfterFirstImage:));

@end

NS_ASSUME_NONNULL_END
