#import <Foundation/Foundation.h>
#import "MXSAESCryptor.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AESGCMCryptor)
@interface MXSAESGCMCryptor : NSObject

// This cryptor appends tag of tagLength to the cipher on encryption, and
// expect a tag on trailing of cipher on decryption. Feel free to change
// this behavior if needed
@property (class, assign, readonly) NSInteger tagLength;

+ (NSData * _Nullable)encrypt:(NSData *)plainData
                      withKey:(NSData *)key
                           iv:(NSData *)iv
                        error:(NSError * _Nullable *)outError NS_SWIFT_NAME(encrypt(_:with:iv:));

+ (NSData * _Nullable)decrypt:(NSData *)cipherData
                      withKey:(NSData *)key
                           iv:(NSData *)iv
                        error:(NSError * _Nullable *)outError NS_SWIFT_NAME(decrypt(_:with:iv:));

@end

NS_ASSUME_NONNULL_END
