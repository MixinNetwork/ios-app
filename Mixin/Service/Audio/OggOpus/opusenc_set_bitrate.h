#ifndef opusenc_set_bitrate_h
#define opusenc_set_bitrate_h

#import "opusenc.h"

// Swift doesn't import C functions that use the ... syntax for variadic arguments
// Add a function to wrap the ope_encoder_ctl function
int ope_encoder_set_bitrate(OggOpusEnc *enc, int bitrate);

#endif /* opusenc_set_bitrate_h */
