#import "MXSMarkdownImageAttachment.h"

@implementation MXSMarkdownImageAttachment

- (CGRect)attachmentBoundsForTextContainer:(nullable NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex {
    if (textContainer == nil) {
        return CGRectMake(0, 0, 900, 338);
    }
    CGFloat height = round(textContainer.size.width / 900 * 338);
    return CGRectMake(0, 0, textContainer.size.width, height);
}

@end
