#import "MXNFastURLDetector.h"

@implementation MXNFastURLDetector

+ (NSDataDetector *)detector {
    static NSDataDetector *detector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    });
    return detector;
}

- (void)enumerateMatchesInAttributedString:(NSAttributedString *)attributedString options:(NSMatchingOptions)options usingBlock:(void (NS_NOESCAPE ^)(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL *stop))block {
    if (attributedString.length < 3) {
        return;
    }
    NSString *string = attributedString.string;
    BOOL maybeContainsURL = NO;
    int sequenceCount = 0; // Sequence of "://"
    SEL selector = @selector(characterAtIndex:);
    unichar (*characterAtIndexImp)(id, SEL, NSUInteger) = (unichar (*)(id, SEL, NSUInteger))[string methodForSelector:selector];
    unichar lastChar = characterAtIndexImp(string, selector, 0);
    for (NSUInteger i = 1; i < string.length - 1; i++) {
        unichar c = characterAtIndexImp(string, selector, i);
        if (c == ':') {
            if (sequenceCount == 0 && lastChar != ' ') {
                sequenceCount++;
            } else {
                sequenceCount = 0;
            }
        } else if (c == '/') {
            if (sequenceCount == 1 || sequenceCount == 2) {
                sequenceCount++;
            } else {
                sequenceCount = 0;
            }
        } else if (c != ' ' && sequenceCount == 3) {
            maybeContainsURL = YES;
            break;
        } else {
            sequenceCount = 0;
        }
        lastChar = c;
    }
    if (maybeContainsURL) {
        NSRange range = NSMakeRange(0, string.length);
        [[MXNFastURLDetector detector] enumerateMatchesInString:string options:options range:range usingBlock:block];
    }
}

@end
