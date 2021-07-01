#import <deque>
#import "md4c.h"
#import "MXSMarkdownConverter+AttributedString.h"
#import "MXSMarkdownImageAttachment.h"

static const unsigned int plainTextHeaderLevel = 0;
static const CGFloat plainTextFontSize = 17;

struct Context {
    const NSUInteger charactersLimit;
    const NSUInteger linesLimit;
    NSMutableAttributedString *const output;
    unsigned headerLevel;
    unsigned indentationLevel;
    std::deque<MD_SPANTYPE> spanTypes;
    unsigned numberOfLines;
    bool stop;
    
    Context(NSMutableAttributedString *o, NSUInteger cl, NSUInteger ll)
    : charactersLimit(cl)
    , linesLimit(ll)
    , output(o)
    , headerLevel(plainTextHeaderLevel)
    , indentationLevel(0)
    , numberOfLines(0)
    , stop(false) { }
    
    void detectLimit() {
        bool reaches = output.length >= charactersLimit || numberOfLines >= linesLimit;
        if (reaches) {
            stop = true;
        }
    }
};

@implementation MXSMarkdownConverter (AttributedString)

+ (NSUInteger)unlimitedNumber {
    return NSUIntegerMax;
}

+ (NSAttributedString *)attributedStringFromMarkdownString:(NSString *)markdownString
                                     maxNumberOfCharacters:(NSUInteger)maxNumberOfCharacters
                                          maxNumberOfLines:(NSUInteger)maxNumberOfLines {
    NSMutableAttributedString *output = [NSMutableAttributedString new];
    MD_PARSER parser = {
        0,
        MD_DIALECT_GITHUB,
        enterBlock,
        leaveBlock,
        enterSpan,
        leaveSpan,
        enterText,
        NULL,
        NULL
    };
    const char* str = markdownString.UTF8String;
    const size_t size = strlen(str);
    Context *const ctx = new Context(output, maxNumberOfCharacters, maxNumberOfLines);
    md_parse(str, (MD_SIZE)size, &parser, ctx);
    NSDictionary *attributes = attributesFromContext(ctx, 1);
    delete ctx;
    
    NSString *plain = output.string;
    NSRange range = [plain rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet
                                           options:NSBackwardsSearch];
    while (range.length != 0 && NSMaxRange(range) == plain.length) {
        [output replaceCharactersInRange:range withString:@""];
        range = [plain rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet
                                       options:NSBackwardsSearch];
    }
    auto linebreak = [[NSAttributedString alloc] initWithString:@"\n" attributes:attributes];
    [output appendAttributedString:linebreak];
    
    return [output copy];
}

NSDictionary *attributesFromContext(Context *ctx, CGFloat lineHeightMultiple) {
    CGFloat fontSize = plainTextFontSize;
    if (ctx->headerLevel != plainTextHeaderLevel) {
        // Factors are from post.css
        switch (ctx->headerLevel) {
            case 1: // <h1>
                fontSize *= 1.58;
                break;
            case 2: // <h2>
                fontSize *= 1.294;
                break;
            case 3: // <h3>
                fontSize *= 1.176;
                break;
            case 4: // <h4>
                fontSize *= 1;
                break;
            case 5: // <h5>
                fontSize *= 0.882;
                break;
            case 6: // <h6>
                fontSize *= 0.765;
                break;
            default:
                fontSize *= 0.941;
                break;
        }
    } else {
        fontSize *= 0.941;
    }
    
    UIFontDescriptorSymbolicTraits traits = 0;
    for (auto type : ctx->spanTypes) {
        switch (type) {
            case MD_SPAN_EM:
                traits |= UIFontDescriptorTraitItalic;
                break;
            case MD_SPAN_STRONG:
                traits |= UIFontDescriptorTraitBold;
            default:
                break;
        }
    }
    
    UIFont *font = [UIFont systemFontOfSize:fontSize];
    UIFontDescriptor *desc = [font.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    font = [UIFont fontWithDescriptor:desc size:0];
    font = [UIFontMetrics.defaultMetrics scaledFontForFont:font];
    
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    if (lineHeightMultiple != 1) {
        style.lineHeightMultiple = lineHeightMultiple;
    } else if (ctx->indentationLevel > 0) {
        style.lineHeightMultiple = 1.1;
    } else {
        style.lineHeightMultiple = 1.2;
    }
    CGFloat margin = ctx->indentationLevel * 33;
    style.headIndent = margin;
    style.firstLineHeadIndent = margin;
    
    return @{
        NSFontAttributeName : font,
        NSParagraphStyleAttributeName : style,
#if DEBUG_POST_LAYOUT
        NSForegroundColorAttributeName : UIColor.labelColor
#endif
    };
}

void appendLinebreak(Context *context, CGFloat heightMultiple) {
    NSString *plain = context->output.string;
    NSUInteger length = plain.length;
    NSDictionary *attributes = attributesFromContext(context, heightMultiple);
    NSAttributedString *linebreak;
    if (length >= 2 && [[plain substringFromIndex:length - 2] isEqualToString:@"\n\n"]) {
        return;
    } else if (length >= 1 && [[plain substringFromIndex:length - 1] isEqualToString:@"\n"]) {
        linebreak = [[NSAttributedString alloc] initWithString:@"\n" attributes:attributes];
    } else {
        linebreak = [[NSAttributedString alloc] initWithString:@"\n\n" attributes:attributes];
    }
    [context->output appendAttributedString:linebreak];
    context->numberOfLines++;
}

int enterBlock(MD_BLOCKTYPE type, void* detail, void* userdata) {
    Context *context = static_cast<Context*>(userdata);
    if (context->stop) {
        return -1;
    }
    
    switch (type) {
        case MD_BLOCK_H: {
            context->headerLevel = static_cast<MD_BLOCK_H_DETAIL*>(detail)->level;
            break;
        }
        case MD_BLOCK_QUOTE:
        case MD_BLOCK_CODE:
            appendLinebreak(context, 1);
        case MD_BLOCK_UL:
        case MD_BLOCK_OL:
        case MD_BLOCK_LI:
            context->indentationLevel++;
            break;
        default:
            break;
    }
    
    context->detectLimit();
    return context->stop;
}

int leaveBlock(MD_BLOCKTYPE type, void* detail, void* userdata) {
    Context *context = static_cast<Context*>(userdata);
    if (context->stop) {
        return -1;
    }
    
    switch (type) {
        case MD_BLOCK_H: {
            unsigned level = static_cast<MD_BLOCK_H_DETAIL*>(detail)->level;
            if (level == 1 || level == 2) {
                UIFont *font = [UIFont systemFontOfSize:plainTextFontSize * 1.3];
                font = [UIFontMetrics.defaultMetrics scaledFontForFont:font];
                NSDictionary *attributes = @{NSFontAttributeName : font};
                NSAttributedString *linebreak = [[NSAttributedString alloc] initWithString:@"\n\n" attributes:attributes];
                [context->output appendAttributedString:linebreak];
                context->numberOfLines++;
            }
            context->headerLevel = plainTextHeaderLevel;
            break;
        }
        case MD_BLOCK_QUOTE:
        case MD_BLOCK_CODE: {
            context->indentationLevel--;
            appendLinebreak(context, 1);
            break;
        }
        case MD_BLOCK_UL:
        case MD_BLOCK_OL:
        case MD_BLOCK_LI:
            context->indentationLevel--;
            break;
        default:
            break;
    }
    appendLinebreak(context, 0.7);
    
    context->detectLimit();
    return context->stop;
}

int enterSpan(MD_SPANTYPE type, void* detail, void* userdata) {
    Context *context = static_cast<Context*>(userdata);
    if (context->stop) {
        return -1;
    }
    
    context->spanTypes.push_back(type);
    if (type == MD_SPAN_IMG) {
        bool hasEnoughTextBeforeImage = context->numberOfLines > 1 || context->output.length > 5;
        auto *attachment = [MXSMarkdownImageAttachment new];
        auto *string = [NSAttributedString attributedStringWithAttachment:attachment];
        [context->output appendAttributedString:string];
        if (hasEnoughTextBeforeImage) {
            appendLinebreak(context, 0.7);
            context->stop = true;
            return -1;
        }
    }
    
    return 0;
}

int leaveSpan(MD_SPANTYPE type, void* detail, void* userdata) {
    Context *context = static_cast<Context*>(userdata);
    if (context->stop) {
        return -1;
    }
    if (!context->spanTypes.empty()) {
        context->spanTypes.pop_back();
    }
    context->detectLimit();
    return context->stop;
}

int enterText(MD_TEXTTYPE type, const MD_CHAR* text, MD_SIZE size, void* userdata) {
    Context *context = static_cast<Context*>(userdata);
    if (context->stop) {
        return -1;
    }
    
    NSString *string = [[NSString alloc] initWithBytes:text length:size encoding:NSUTF8StringEncoding];
    NSUInteger numberOfLines = 0, length = string.length;
    NSRange range = NSMakeRange(0, length);
    while (range.location != NSNotFound) {
        range = [string rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet
                                        options:0
                                          range:range];
        if (range.location != NSNotFound) {
            range = NSMakeRange(range.location + range.length, length - (range.location + range.length));
            numberOfLines++;
        }
    }
    
    NSDictionary *attributes = attributesFromContext(context, 1);
    NSAttributedString *newOutput = [[NSAttributedString alloc] initWithString:string attributes:attributes];
    [context->output appendAttributedString:newOutput];
    context->numberOfLines += numberOfLines;
    context->detectLimit();
    return context->stop;
}

@end
