#import "MXSEd25519PublicKey.h"
#include <openssl/curve25519.h>

@implementation MXSEd25519PublicKey {
    uint8_t _bytes[ED25519_PUBLIC_KEY_LEN];
}

- (instancetype)initWithBytes:(uint8_t *)bytes {
    self = [super init];
    if (self) {
        memcpy(_bytes, bytes, ED25519_PUBLIC_KEY_LEN);
    }
    return self;
}

- (NSData *)rawRepresentation {
    return [NSData dataWithBytes:_bytes length:ED25519_PUBLIC_KEY_LEN];
}

@end
