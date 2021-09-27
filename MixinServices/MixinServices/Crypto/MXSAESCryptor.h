#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_CLOSED_ENUM(NSInteger, MXSAESCryptorPadding) {
    MXSAESCryptorPaddingNone,
    MXSAESCryptorPaddingPKCS7 NS_SWIFT_NAME(pkcs7)
} NS_SWIFT_NAME(AESCryptorPadding);

NS_SWIFT_NAME(AESCryptor)
@interface MXSAESCryptor : NSObject

+ (NSData * _Nullable)encrypt:(NSData *)plainData
                      withKey:(NSData *)key
                           iv:(NSData *)iv
                      padding:(MXSAESCryptorPadding)padding
                        error:(NSError * _Nullable *)outError NS_SWIFT_NAME(encrypt(_:with:iv:padding:));

+ (NSData * _Nullable)decrypt:(NSData *)cipher
                      withKey:(NSData *)key
                           iv:(NSData *)iv
                        error:(NSError * _Nullable *)outError NS_SWIFT_NAME(decrypt(_:with:iv:));

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
