#import "MXSEd25519PublicKey.h"
#include <openssl/curve25519.h>

@implementation MXSEd25519PublicKey {
    NSData *_raw;
}

- (instancetype)initWithBytesNoCopy:(uint8_t *)bytes length:(NSUInteger)length freeWhenDone:(BOOL)b {
    self = [super init];
    if (self) {
        _raw = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:b];
    }
    return self;
}

- (NSData *)rawRepresentation {
    return _raw;
}

@end
