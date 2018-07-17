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
    NSString *string = attributedString.string;
    BOOL maybeContainsURL = NO;
    int dotSequence = 0;
    unichar lastChar = 0;
    SEL selector = @selector(characterAtIndex:);
    unichar (*characterAtIndexImp)(id, SEL, NSUInteger) = (unichar (*)(id, SEL, NSUInteger))[string methodForSelector:selector];
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = characterAtIndexImp(string, selector, i);
        if (c == '.') {
            if (dotSequence == 0 && lastChar != ' ') {
                dotSequence++;
            } else {
                dotSequence = 0;
            }
        } else if (c != ' ' && lastChar == '.' && dotSequence == 1) {
            maybeContainsURL = YES;
            break;
        } else {
            dotSequence = 0;
        }
        lastChar = c;
    }
    if (maybeContainsURL) {
        NSRange range = NSMakeRange(0, string.length);
        [[MXNFastURLDetector detector] enumerateMatchesInString:string options:options range:range usingBlock:block];
    }
}

@end
