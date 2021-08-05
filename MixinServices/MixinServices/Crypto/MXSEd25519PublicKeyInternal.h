#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MXSEd25519PublicKey (MXSEd25519PublicKeyProtected)

- (instancetype)initWithBytesNoCopy:(uint8_t *)bytes length:(NSUInteger)length freeWhenDone:(BOOL)b;

@end

NS_ASSUME_NONNULL_END
