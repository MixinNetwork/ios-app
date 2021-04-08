#import "MXSMarkdownConverter.h"
#import "md4c.h"

// Swift doesn't work here because MD_DIALECT_GITHUB is not representable
@implementation MXSMarkdownConverter

int processPlainTextOutput(MD_TEXTTYPE type, const MD_CHAR* text, MD_SIZE size, void* userdata) {
    if (!text) {
        return 0;
    }
    NSMutableString *writeBack = (__bridge NSMutableString *)(userdata);
    NSString *newOutput = [[NSString alloc] initWithBytesNoCopy:(void *)text
                                                         length:size
                                                       encoding:NSUTF8StringEncoding
                                                   freeWhenDone:NO];
    if (newOutput) {
        [writeBack appendString:newOutput];
    }
    return 0;
}

int processPlainTextBlock(MD_BLOCKTYPE type, void* detail, void* userdata) {
    return 0;
}

int processPlainTextSpan(MD_SPANTYPE type, void* detail, void* userdata) {
    return 0;
}

+ (NSString *)plainTextFromMarkdownString:(NSString *)markdownString {
    NSMutableString *output = [NSMutableString new];
    const char* md = markdownString.UTF8String;
    size_t size = strlen(md);
    MD_PARSER parser = {
        0,
        MD_DIALECT_GITHUB,
        processPlainTextBlock,
        processPlainTextBlock,
        processPlainTextSpan,
        processPlainTextSpan,
        processPlainTextOutput,
        NULL,
        NULL
    };
    md_parse(md, (MD_SIZE)size, &parser, (__bridge void *)(output));
    return [output copy];
}

@end
