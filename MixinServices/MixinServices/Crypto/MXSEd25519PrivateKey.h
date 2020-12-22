#import <Foundation/Foundation.h>
#import "MXSEd25519PublicKey.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Ed25519PrivateKey)
@interface MXSEd25519PrivateKey : NSObject

@property (nonatomic, strong, readonly) MXSEd25519PublicKey *publicKey;
@property (nonatomic, strong, readonly) NSData *rfc8032Representation;
@property (nonatomic, strong, readonly) NSData *x25519Representation;

- (instancetype)initWithRFC8032Representation:(NSData *)seed;
- (instancetype)init;
- (NSData * _Nullable)signatureForData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
