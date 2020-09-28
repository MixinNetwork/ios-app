#import <Foundation/Foundation.h>
#import "MXCEd25519PublicKey.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Ed25519PrivateKey)
@interface MXCEd25519PrivateKey : NSObject

@property (nonatomic, strong, readonly) MXCEd25519PublicKey *publicKey;
@property (nonatomic, strong, readonly) NSData *rfc8032Representation;
@property (nonatomic, strong, readonly) NSData *x25519Representation;

- (instancetype)initWithRFC8032Representation:(NSData *)seed;
- (instancetype)init;
- (NSData * _Nullable)signatureForData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
