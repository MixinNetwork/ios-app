#import "opusenc_set_bitrate.h"

int ope_encoder_set_bitrate(OggOpusEnc *enc, int bitrate) {
    return ope_encoder_ctl(enc, OPUS_SET_BITRATE_REQUEST, bitrate);
}
