import Foundation
import SDWebImage

final class WebPImageDecoder: NSObject {
    
    static let shared = WebPImageDecoder(decoder: nil)
    
    private var decoder: WebPImageDecoderInternal?
    
    private init(decoder: WebPImageDecoderInternal?) {
        self.decoder = decoder
        super.init()
    }
    
}

// MARK: - SDImageCoder
extension WebPImageDecoder: SDImageCoder {
    
    func canDecode(from data: Data?) -> Bool {
        isWebP(data: data)
    }
    
    func decodedImage(with data: Data?, options: [SDImageCoderOption : Any]? = nil) -> UIImage? {
        guard let data = data else {
            return nil
        }
        let scale = options?[.decodeScaleFactor] as? CGFloat ?? 1
        guard let decoder = WebPImageDecoderInternal(data: data, scale: scale) else {
            return nil
        }
        let image: UIImage?
        let firstFrameOnly = (options?[.decodeFirstFrameOnly] as? Bool) ?? false
        if firstFrameOnly || decoder.frameCount == 1 {
            image = decoder.frame(at: 0)?.image
        } else {
            let frames: [SDImageFrame] = (0..<decoder.frameCount).compactMap { i in
                guard let imageFrame = decoder.frame(at: i) else {
                    return nil
                }
                guard let image = imageFrame.image else {
                    return nil
                }
                return SDImageFrame(image: image, duration: imageFrame.duration)
            }
            image = SDImageCoderHelper.animatedImage(with: frames)
            image?.sd_imageLoopCount = decoder.loopCount
        }
        image?.sd_imageFormat = .webP
        return image
    }
    
    func canEncode(to format: SDImageFormat) -> Bool {
        // According to source code of SDWebImage, there're two scenarios that need encoding,
        // one is to store a UIImage to SDImageCache, another is to transcode with UIImage+MultiFormat
        // Just leave it false since we're not using any of them.
        assertionFailure("Not yet needed")
        return false
    }
    
    func encodedData(with image: UIImage?, format: SDImageFormat, options: [SDImageCoderOption : Any]? = nil) -> Data? {
        nil
    }
    
}

// MARK: - SDAnimatedImageCoder
extension WebPImageDecoder: SDAnimatedImageCoder {
    
    convenience init?(animatedImageData data: Data?, options: [SDImageCoderOption : Any]? = nil) {
        let scale = options?[.decodeScaleFactor] as? CGFloat ?? 1
        guard let data = data, let decoder = WebPImageDecoderInternal(data: data, scale: scale) else {
            return nil
        }
        self.init(decoder: decoder)
    }
    
}

// MARK: - SDAnimatedImageProvider
extension WebPImageDecoder: SDAnimatedImageProvider {
    
    var animatedImageData: Data? {
        decoder?.data
    }
    
    var animatedImageFrameCount: UInt {
        decoder?.frameCount ?? 0
    }
    
    var animatedImageLoopCount: UInt {
        decoder?.loopCount ?? 0
    }
    
    func animatedImageFrame(at index: UInt) -> UIImage? {
        decoder?.frame(at: index)?.image
    }
    
    func animatedImageDuration(at index: UInt) -> TimeInterval {
        decoder?.frameDuration(at: index) ?? 0
    }
    
}

// MARK: - Detector
extension WebPImageDecoder {
    
    private enum FourCC {
        
        static let riff: [UInt8] = [
            UInt8(ascii: "R"),
            UInt8(ascii: "I"),
            UInt8(ascii: "F"),
            UInt8(ascii: "F")
        ]
        
        static let webp: [UInt8] = [
            UInt8(ascii: "W"),
            UInt8(ascii: "E"),
            UInt8(ascii: "B"),
            UInt8(ascii: "P")
        ]
        
    }
    
    private func isWebP(data: Data?) -> Bool {
        guard let data = data, data.count > 12 else {
            return false
        }
        let isWebP = (0...3).allSatisfy { i in
            // https://developers.google.com/speed/webp/docs/riff_container
            data[i] == FourCC.riff[i] && data[i + 8] == FourCC.webp[i]
        }
        return isWebP
    }
    
}
