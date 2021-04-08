#import "MXSMarkdownConverter.h"
#import "md4c.h"
#import "md4c-html.h"

// Swift doesn't work here because MD_DIALECT_GITHUB is not representable
@implementation MXSMarkdownConverter

// NSString doesn't support multilined raw string literal, we borrow it from C++ 11
const char *richHeader = R"(
<!DOCTYPE html>
<html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="github-markdown.css">
        <link rel="stylesheet" href="code.css">
        <script src="highlight.js"></script>
        <script>hljs.highlightAll();</script>
        <style>
            .markdown-body {
                box-sizing: border-box;
                min-width: 200px;
                max-width: 980px;
                margin: 0 auto;
                padding: 45px;
            }
            @media (max-width: 767px) {
                .markdown-body {
                    padding: 15px;
                }
            }
        </style>
    </head>
    <body>
    <article class="markdown-body">
)";

const char *plainHeader = R"(
<!DOCTYPE html>
<html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="github-markdown.css">
    </head>
    <body>
    <article class="markdown-body">
)";

NSString *const footer = @"</article></body></html>";

void processHTMLOutput(const MD_CHAR *output, MD_SIZE size, void *userData);
int processPlainTextOutput(MD_TEXTTYPE type, const MD_CHAR* text, MD_SIZE size, void* userdata);
int processPlainTextBlock(MD_BLOCKTYPE type, void* detail, void* userdata);
int processPlainTextSpan(MD_SPANTYPE type, void* detail, void* userdata);

+ (NSString *)htmlStringFromMarkdownString:(NSString *)markdownString richFormat:(BOOL)rich {
    NSMutableString *output;
    if (rich) {
        output = [[NSMutableString alloc] initWithCString:richHeader encoding:NSUTF8StringEncoding];
    } else {
        output = [[NSMutableString alloc] initWithCString:plainHeader encoding:NSUTF8StringEncoding];
    }
    const char *cMarkdown = [markdownString cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = strlen(cMarkdown);
    md_html(cMarkdown, (MD_SIZE)length, &processHTMLOutput, (__bridge void *)(output), MD_DIALECT_GITHUB, 0);
    [output appendString:footer];
    return output;
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

void processHTMLOutput(const MD_CHAR *output, MD_SIZE size, void *userData) {
    if (!output) {
        return;
    }
    NSMutableString *writeBack = (__bridge NSMutableString *)(userData);
    NSString *newOutput = [[NSString alloc] initWithBytesNoCopy:(void *)output
                                                         length:size
                                                       encoding:NSUTF8StringEncoding
                                                   freeWhenDone:NO];
    if (newOutput) {
        [writeBack appendString:newOutput];
    }
}

@end
