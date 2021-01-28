#import "MXMMarkdownConverter.h"
#import "md4c.h"
#import "md4c-html.h"

// Swift doesn't work here because MD_DIALECT_GITHUB is not representable
@implementation MXMMarkdownConverter

// NSString doesn't support multilined raw string literal, we borrow it from C++ 11
const char *header = R"(
<!DOCTYPE html>
<html>
 <head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
   body {
    font: 16px Arial, sans-serif;
   }
   img {
    width:auto;
    height:auto;
    max-width:100%;
    max-height:90vh;
   }
  </style>
 </head>
<body>
)";

NSString *const footer = @"</body></html>";

void ProcessOutput(const MD_CHAR * output, MD_SIZE size, void *userData);

+ (NSString *)htmlStringFromMarkdownString:(NSString *)markdownString {
    NSMutableString *output = [[NSMutableString alloc] initWithCString:header encoding:NSUTF8StringEncoding];
    const char *cMarkdown = [markdownString cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = strlen(cMarkdown);
    md_html(cMarkdown, (MD_SIZE)length, &ProcessOutput, (__bridge void *)(output), MD_DIALECT_GITHUB, 0);
    [output appendString:footer];
    return output;
}

void ProcessOutput(const MD_CHAR * output, MD_SIZE size, void *userData) {
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
