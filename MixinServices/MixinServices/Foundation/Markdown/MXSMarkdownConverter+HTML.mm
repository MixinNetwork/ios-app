#import "MXSMarkdownConverter+HTML.h"
#import "md4c.h"
#import "md4c-html.h"

@implementation MXSMarkdownConverter (HTML)

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

@end
