import Foundation
import SDWebImage
import libwebp

class WebPImageDecoderInternal {
    
    class ImageFrame {
        
        let index: UInt
        let frame: CGRect
        let duration: TimeInterval
        let disposeBackground: Bool
        let blend: Bool
        let blendFromIndex: UInt
        
        var image: UIImage?
        
        init(
            index: UInt,
            frame: CGRect,
            duration: TimeInterval,
            disposeBackground: Bool,
            blend: Bool,
            blendFromIndex: UInt
        ) {
            self.index = index
            self.frame = frame
            self.duration = duration
            self.disposeBackground = disposeBackground
            self.blend = blend
            self.blendFromIndex = blendFromIndex
        }
        
    }
    
    private static let bitmapInfo: CGBitmapInfo = {
        let byteOrder: CGBitmapInfo
        if CFByteOrderGetCurrent() == CFByteOrderBigEndian.rawValue {
            byteOrder = .byteOrder32Big
        } else {
            byteOrder = .byteOrder32Little
        }
        return [byteOrder, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)]
    }()
    
    let scale: CGFloat
    let frameCount: UInt
    let loopCount: UInt
    let data: Data
    
    private let lock = NSRecursiveLock()
    private let colorSpace: CGColorSpace
    private let demux: OpaquePointer
    private let canvasSize: CGSize
    private let frames: [ImageFrame]
    private let needsBlend: Bool
    
    private var blendFrameIndex: UInt?
    private var blendContext: CGContext?
    
    init?(data: Data, scale: CGFloat) {
        let demux: OpaquePointer? = data.withUnsafeUInt8Pointer { ptr in
            var webpData = WebPData()
            webpData.bytes = ptr
            webpData.size = data.count
            return WebPDemux(&webpData)
        }
        guard let demux = demux else {
            return nil
        }
        
        let embeddedColorSpace: CGColorSpace? = {
            guard WebPDemuxGetI(demux, WEBP_FF_FORMAT_FLAGS) & ICCP_FLAG.rawValue != 0 else {
                return nil
            }
            var it = WebPChunkIterator()
            let result = "ICCP".withCString { iccp in
                WebPDemuxGetChunk(demux, iccp, 1, &it)
            }
            guard result != 0 else {
                return nil
            }
            let profile = Data(bytes: it.chunk.bytes, count: it.chunk.size)
            WebPDemuxReleaseChunkIterator(&it)
            guard let space = CGColorSpace(iccData: profile as CFData) else {
                return nil
            }
            if space.model == .rgb {
                return space
            } else {
                return nil
            }
        }()
        
        let frameCount = WebPDemuxGetI(demux, WEBP_FF_FRAME_COUNT)
        let loopCount = WebPDemuxGetI(demux, WEBP_FF_LOOP_COUNT)
        let canvasSize = CGSize(width: CGFloat(WebPDemuxGetI(demux, WEBP_FF_CANVAS_WIDTH)),
                                height: CGFloat(WebPDemuxGetI(demux, WEBP_FF_CANVAS_HEIGHT)))
        guard frameCount != 0 && canvasSize.width >= 1 && canvasSize.height >= 1 else {
            WebPDemuxDelete(demux)
            return nil
        }
        
        var frames: [ImageFrame] = []
        var needsBlend = false
        var lastBlendedIndex: UInt = 0
        var it = WebPIterator()
        var itIndex: UInt = 0
        
        frames.reserveCapacity(Int(frameCount))
        if WebPDemuxGetFrame(demux, 1, &it) != 0 {
            repeat {
                let frame = CGRect(x: CGFloat(it.x_offset),
                                   y: canvasSize.height - CGFloat(it.y_offset + it.height),
                                   width: CGFloat(it.width),
                                   height: CGFloat(it.height))
                let disposeBackground = it.dispose_method == WEBP_MUX_DISPOSE_BACKGROUND
                let blend = it.blend_method == WEBP_MUX_BLEND
                let hasAlpha = it.has_alpha != 0
                let isFullSize = frame.origin == .zero
                    && canvasSize.width == frame.width
                    && canvasSize.height == frame.height
                let blendFromIndex: UInt
                if (!blend || !hasAlpha) && isFullSize {
                    blendFromIndex = itIndex
                    lastBlendedIndex = itIndex
                } else {
                    blendFromIndex = lastBlendedIndex
                    if disposeBackground && isFullSize {
                        lastBlendedIndex = itIndex + 1
                    }
                }
                if itIndex != blendFromIndex {
                    needsBlend = true
                }
                let imageFrame = ImageFrame(index: itIndex,
                                            frame: frame,
                                            duration: TimeInterval(it.duration) / 1000,
                                            disposeBackground: disposeBackground,
                                            blend: blend,
                                            blendFromIndex: blendFromIndex)
                frames.append(imageFrame)
                itIndex += 1
            } while WebPDemuxNextFrame(&it) != 0
            WebPDemuxReleaseIterator(&it)
        }
        
        guard frames.count == frameCount else {
            WebPDemuxDelete(demux)
            return nil
        }
        if scale < 1 {
            self.scale = 1
        } else {
            self.scale = scale
        }
        self.frameCount = UInt(frameCount)
        self.loopCount = UInt(loopCount)
        self.data = data
        self.colorSpace = embeddedColorSpace ?? SDImageCoderHelper.colorSpaceGetDeviceRGB()
        self.demux = demux
        self.canvasSize = canvasSize
        self.frames = frames
        self.needsBlend = needsBlend
    }
    
    deinit {
        WebPDemuxDelete(demux)
    }
    
    func frameDuration(at index: UInt) -> TimeInterval {
        var duration: TimeInterval = 0
        if index < frames.count {
            duration = frames[Int(index)].duration
        }
        return duration
    }
    
    func frame(at index: UInt) -> ImageFrame? {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard index <= frames.count else {
            return nil
        }
        let frame = frames[Int(index)]
        if frame.image != nil {
            return frame
        } else if needsBlend {
            guard let cgImage = makeBlendedImage(at: index) else {
                return nil
            }
            frame.image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
            return frame
        } else {
            guard let cgImage = makeUnblendedImage(at: index) else {
                return nil
            }
            frame.image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
            return frame
        }
    }
    
}

extension WebPImageDecoderInternal {
    
    private func align(value: Int, to alignment: Int) -> Int {
        let (quotient, remainder) = value.quotientAndRemainder(dividingBy: alignment)
        if remainder == 0 {
            return quotient * alignment
        } else {
            return (quotient + 1) * alignment
        }
    }
    
    private func makeUnblendedImage(at index: UInt) -> CGImage? {
        guard index < frames.count else {
            return nil
        }
        var it = WebPIterator()
        guard WebPDemuxGetFrame(demux, Int32(index + 1), &it) != 0 else {
            return nil
        }
        let frameSize = CGSize(width: CGFloat(it.width), height: CGFloat(it.height))
        let isFrameSizeValid = frameSize.width >= 1
            && frameSize.width <= canvasSize.width
            && frameSize.height >= 1
            && frameSize.height <= canvasSize.height
        guard isFrameSizeValid else {
            return nil
        }
        
        var config = WebPDecoderConfig()
        guard WebPInitDecoderConfig(&config) != 0 else {
            WebPDemuxReleaseIterator(&it)
            return nil
        }
        guard WebPGetFeatures(it.fragment.bytes, it.fragment.size, &config.input) == VP8_STATUS_OK else {
            WebPDemuxReleaseIterator(&it)
            return nil
        }
        
        let bitsPerComponent = 8
        let bitsPerPixel = 32
        let bytesPerRow = align(value: bitsPerPixel / 8 * Int(frameSize.width), to: 32)
        let length = bytesPerRow * Int(frameSize.height)
        guard let pixels = calloc(1, length) else {
            WebPDemuxReleaseIterator(&it)
            return nil
        }
        
        config.output.colorspace = MODE_bgrA
        config.output.is_external_memory = 1
        config.output.u.RGBA.rgba = pixels.assumingMemoryBound(to: UInt8.self)
        config.output.u.RGBA.stride = Int32(bytesPerRow)
        config.output.u.RGBA.size = length
        
        let result = WebPDecode(it.fragment.bytes, it.fragment.size, &config)
        WebPDemuxReleaseIterator(&it)
        guard result == VP8_STATUS_OK || result == VP8_STATUS_NOT_ENOUGH_DATA else {
            free(pixels)
            return nil
        }
        
        let provider = CGDataProvider(dataInfo: pixels, data: pixels, size: length) { info, _, _ in
            if let info = info {
                free(info)
            }
        }
        guard let provider = provider else {
            free(pixels)
            return nil
        }
        let image = CGImage(width: Int(frameSize.width),
                            height: Int(frameSize.height),
                            bitsPerComponent: bitsPerComponent,
                            bitsPerPixel: bitsPerPixel,
                            bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: Self.bitmapInfo,
                            provider: provider,
                            decode: nil,
                            shouldInterpolate: false,
                            intent: .defaultIntent)
        return image
    }
    
    private func blendImage(imageFrame: ImageFrame, with context: CGContext) -> CGImage? {
        var image: CGImage?
        if imageFrame.disposeBackground {
            if imageFrame.blend {
                // TODO: This routine has not been tested. Find a image that matches
                if let unblended = makeUnblendedImage(at: imageFrame.index) {
                    context.draw(unblended, in: imageFrame.frame)
                }
                image = context.makeImage()
                context.clear(imageFrame.frame)
            } else {
                if let unblended = makeUnblendedImage(at: imageFrame.index) {
                    context.clear(imageFrame.frame)
                    context.draw(unblended, in: imageFrame.frame)
                }
                image = context.makeImage()
                context.clear(imageFrame.frame)
            }
        } else {
            if imageFrame.blend {
                if let unblended = makeUnblendedImage(at: imageFrame.index) {
                    context.draw(unblended, in: imageFrame.frame)
                }
                image = context.makeImage()
            } else {
                if let unblended = makeUnblendedImage(at: imageFrame.index) {
                    context.clear(imageFrame.frame)
                    context.draw(unblended, in: imageFrame.frame)
                }
                image = context.makeImage()
            }
        }
        return image
    }
    
    private func makeBlendedImage(at index: UInt) -> CGImage? {
        guard index < frames.count else {
            return nil
        }
        if blendContext == nil {
            blendContext = CGContext(data: nil,
                                     width: Int(canvasSize.width),
                                     height: Int(canvasSize.height),
                                     bitsPerComponent: 8,
                                     bytesPerRow: 0,
                                     space: colorSpace,
                                     bitmapInfo: Self.bitmapInfo.rawValue)
        }
        guard let context = blendContext else {
            return nil
        }
        
        let imageFrame = frames[Int(index)]
        var cgImage: CGImage?
        if let blendFrameIndex = blendFrameIndex, blendFrameIndex + 1 == imageFrame.index {
            cgImage = blendImage(imageFrame: imageFrame, with: context)
            self.blendFrameIndex = index
        } else {
            blendFrameIndex = nil
            context.clear(CGRect(origin: .zero, size: canvasSize))
            if imageFrame.blendFromIndex == imageFrame.index {
                if let unblended = makeUnblendedImage(at: index) {
                    context.draw(unblended, in: imageFrame.frame)
                }
                cgImage = context.makeImage()
                if imageFrame.disposeBackground {
                    context.clear(imageFrame.frame)
                }
            } else {
                for i in imageFrame.blendFromIndex...imageFrame.index {
                    if i == imageFrame.index {
                        if cgImage == nil {
                            cgImage = blendImage(imageFrame: imageFrame, with: context)
                        }
                    } else {
                        if imageFrame.disposeBackground {
                            context.clear(imageFrame.frame)
                        } else {
                            if imageFrame.blend {
                                if let unblended = makeUnblendedImage(at: imageFrame.index) {
                                    context.draw(unblended, in: imageFrame.frame)
                                }
                            } else {
                                context.clear(imageFrame.frame)
                                if let unblended = makeUnblendedImage(at: imageFrame.index) {
                                    context.draw(unblended, in: imageFrame.frame)
                                }
                            }
                        }
                    }
                }
                blendFrameIndex = index
            }
        }
        return cgImage
    }
    
}
