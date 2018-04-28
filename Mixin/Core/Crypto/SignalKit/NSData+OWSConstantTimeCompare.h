//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (OWSConstantTimeCompare)

/**
 * Compares data in constant time so as to help avoid potential timing attacks.
 */
- (BOOL)ows_constantTimeIsEqualToData:(NSData *)other;

@end

NS_ASSUME_NONNULL_END
