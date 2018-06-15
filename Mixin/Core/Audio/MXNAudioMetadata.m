
#import "MXNAudioMetadata.h"

@implementation MXNAudioMetadata

+ (instancetype)metadataWithDuration:(NSUInteger)duration waveform:(NSData *)waveform {
    return [[MXNAudioMetadata alloc] initWithDuration:duration waveform:waveform];
}

- (instancetype)initWithDuration:(NSUInteger)duration waveform:(NSData *)waveform {
    self = [super init];
    if (self) {
        _duration = duration;
        _waveform = waveform;
    }
    return self;
}

@end
