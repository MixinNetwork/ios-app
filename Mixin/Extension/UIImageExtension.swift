import UIKit
import CoreGraphics
import AVFoundation
import SDWebImage

let jpegCompressionQuality: CGFloat = 0.75

extension UIImage {
    
    var base64: String? {
        let data = self.jpegData(compressionQuality: jpegCompressionQuality)
        return data?.base64EncodedString()
    }

    convenience init?(qrcode: String, size: CGSize, foregroundColor: UIColor? = nil) {
        guard let filter = CIFilter(name: "CIQRCodeGenerator"), !qrcode.isEmpty else {
            return nil
        }

        filter.setDefaults()
        // To create a QR code from a string or URL, convert it to an NSData object using the NSISOLatin1StringEncoding string encoding.
        let data = qrcode.data(using: String.Encoding.isoLatin1)
        filter.setValue(data, forKey: "inputMessage")

        var outputImage: CIImage?
        if let foregroundColor = foregroundColor {
            guard let colorFilter = CIFilter(name: "CIFalseColor") else {
                return nil
            }
            colorFilter.setValue(filter.outputImage, forKey: "inputImage")
            colorFilter.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor1")
            colorFilter.setValue(CIColor(color: foregroundColor), forKey: "inputColor0")
            outputImage = colorFilter.outputImage
        } else {
            outputImage = filter.outputImage
        }

        if let ciImage = outputImage {
            let transform = CGAffineTransform(scaleX: size.width * UIScreen.main.scale / ciImage.extent.width,
                                              y: size.height * UIScreen.main.scale / ciImage.extent.height)
            self.init(ciImage: ciImage.transformed(by: transform))
        } else {
            return nil
        }
    }

    convenience init?(withFirstFrameOfVideoAtAsset asset: AVAsset) {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(value: 0, timescale: 1), actualTime: nil)
            self.init(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    convenience init?(withFirstFrameOfVideoAtURL url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(value: 0, timescale: 1), actualTime: nil)
            self.init(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    func drawText(text: String, offset: CGPoint, fontSize: CGFloat) -> UIImage {
        guard !text.isEmpty else {
            return self
        }
        let targetWidth = self.size.width
        let targetHeight = self.size.height
        let textColor = UIColor.white
        let textFont = UIFont.systemFont(ofSize: fontSize)
        let textFontAttributes = [NSAttributedString.Key.font: textFont, NSAttributedString.Key.foregroundColor: textColor]
        let string = text as NSString
        let stringSize = string.size(withAttributes: textFontAttributes)
        let textRect = CGRect(x: (targetWidth - stringSize.width) / 2 + offset.x,
                              y: (targetHeight - stringSize.height) / 2 + offset.y,
                              width: stringSize.width,
                              height: stringSize.height)
        UIGraphicsBeginImageContextWithOptions(self.size, false, UIScreen.main.scale)
        draw(in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        string.draw(in: textRect, withAttributes: textFontAttributes)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }
        return newImage
    }

    func scaledToSticker() -> UIImage {
        let maxWH: CGFloat = 360
        let scale = CGFloat(size.width) / CGFloat(size.height)
        let targetWidth: CGFloat = size.width > size.height ? maxWH : maxWH * scale
        let targetHeight: CGFloat = size.width > size.height ? maxWH / scale : maxWH
        return scaledToSize(newSize: CGSize(width: targetWidth, height: targetHeight))
    }

    func scaledToSize(newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(newSize)
        draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
    func base64Thumbnail(maxLength: CGFloat = 48) -> String {
        let scaledImage: UIImage
        if max(size.width, size.height) > maxLength {
            var targetSize = size.rect(fittingSize: CGSize(width: maxLength, height: maxLength)).size
            targetSize = CGSize(width: max(1, targetSize.width),
                                height: max(1, targetSize.height))
            scaledImage = scaledToSize(newSize: targetSize)
        } else {
            scaledImage = self
        }
        if let ciImage = scaledImage.ciImage, let filter = CIFilter(name: "CIGaussianBlur") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(4, forKey: kCIInputRadiusKey)
            if let blurImage = filter.outputImage {
                return UIImage(ciImage: blurImage).base64 ?? ""
            }
        }
        return scaledImage.base64 ?? ""
    }
    
    func scaleForUpload() -> UIImage {
        let maxShortSideLength: CGFloat = 1440
        guard min(size.width, size.height) >= maxShortSideLength else {
            return self
        }
        let maxLongSideLength: CGFloat = 1920
        let scale = CGFloat(size.width) / CGFloat(size.height)
        let targetWidth: CGFloat = size.width > size.height ? maxLongSideLength : maxLongSideLength * scale
        let targetHeight: CGFloat = size.width > size.height ? maxLongSideLength / scale : maxLongSideLength
        return scaledToSize(newSize: CGSize(width: targetWidth, height: targetHeight))
    }

    @discardableResult
    func saveToFile(path: URL, quality: CGFloat = jpegCompressionQuality) -> Bool {
        guard let data = self.jpegData(compressionQuality: quality) else {
            return false
        }
        do {
            try data.write(to: path)
            return true
        } catch {
            return false
        }
    }
}

extension UIImage {
    
    static func makeGroupImage(participants: [ParticipantUser]) -> UIImage? {
        let participants = participants.prefix(4)
        let squareRect = CGRect(x: 7.0/34.0, y: 7.0/34.0, width: 20.0/34.0, height: 20.0/34.0)
        let rectangleRect = CGRect(x: 13.0/46.0, y: 3.0/46.0, width: 20.0/46.0, height: 40.0/46.0)

        var images = [UIImage]()
        let relativeTextSize: [CGSize]
        let rectangleSize = CGSize(width: rectangleRect.width * sqrt(2) / 2, height: rectangleRect.height * sqrt(2))
        let squareSize = CGSize(width: squareRect.width * sqrt(2) / 2, height: squareRect.height * sqrt(2) / 2)
        switch participants.count {
        case 0:
            relativeTextSize = []
        case 1:
            relativeTextSize = [CGSize(width: sqrt(2), height: sqrt(2))]
        case 2:
            relativeTextSize = [rectangleSize, rectangleSize]
        case 3:
            relativeTextSize = [rectangleSize, squareSize, squareSize]
        default:
            relativeTextSize = [squareSize, squareSize, squareSize, squareSize]
        }
        let semaphore = DispatchSemaphore(value: 0)
        for (index, participant) in participants.enumerated() {
            if !participant.userAvatarUrl.isEmpty, let url = URL(string: participant.userAvatarUrl) {
                var isSucceed = false
                SDWebImageManager.shared.loadImage(with: url, options: .lowPriority, progress: nil, completed: { (image, _, error, _, _, _) in
                    if let err = error {
                        #if DEBUG
                        print(err)
                        #endif
                    }

                    if error == nil, let image = image {
                        images.append(image)
                        isSucceed = true
                    }
                    semaphore.signal()
                })
                semaphore.wait()
                if !isSucceed {
                    return nil
                }
            } else {
                let colorIndex = participant.userId.positiveHashCode() % 24 + 1
                if let image = UIImage(named: "color\(colorIndex)"), let firstLetter = participant.userFullName.first {
                    let text = String([firstLetter]).uppercased()
                    let textSize = CGSize(width: relativeTextSize[index].width * image.size.width,
                                          height: relativeTextSize[index].height * image.size.height)
                    var offset = self.offset(forIndex: index, of: participants.count)
                    offset.x *= image.size.width
                    offset.y *= image.size.height
                    let avatar = image.drawText(text: text,
                                                offset: offset,
                                                fontSize: fontSize(forText: text, size: textSize))
                    images.append(avatar)
                }
            }
        }

        return images.count == 1 ? images[0] : puzzleImages(rectangleRect: rectangleRect, squareRect: squareRect, images: images)
    }

    private static func fontSize(forText text: String, size greatestSize: CGSize) -> CGFloat {
        let maxFontSize = 17
        let minFontSize = 12
        let nsText = text as NSString
        for i in minFontSize...maxFontSize {
            let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: CGFloat(i))]
            let size = nsText.boundingRect(with: UIView.layoutFittingCompressedSize, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            if size.width > greatestSize.width || size.height > greatestSize.height {
                return CGFloat(i - 1)
            }
        }
        return CGFloat(maxFontSize)
    }

    private static func puzzleImages(rectangleRect: CGRect, squareRect: CGRect, images: [UIImage]) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 512, height: 512)
        let separatorLineWidth: CGFloat = 4 * UIScreen.main.scale

        guard !images.isEmpty else {
            return #imageLiteral(resourceName: "ic_conversation_group")
        }
        let images = images.map { (image) -> UIImage in
            if abs(image.size.width - image.size.height) > 1 {
                if image.size.width > image.size.height {
                    let rect = CGRect(x: (image.size.width - image.size.height) / 2 ,
                                      y: 0,
                                      width: image.size.height,
                                      height: image.size.height)
                    return self.image(withImage: image, rect: rect)
                } else {
                    let rect = CGRect(x: 0,
                                      y: (image.size.height - image.size.width) / 2,
                                      width: image.size.width,
                                      height: image.size.width)
                    return self.image(withImage: image, rect: rect)
                }
            } else {
                return image
            }
        }
        UIGraphicsBeginImageContext(rect.size)
        UIBezierPath(roundedRect: rect, cornerRadius: rect.width / 2).addClip()
        if images.count == 1 {
            images[0].draw(in: rect)
        } else if images.count == 2 {
            let croppedImages = [self.image(withImage: images[0], relativeRect: rectangleRect),
                                 self.image(withImage: images[1], relativeRect: rectangleRect)]
            croppedImages[0].draw(in: CGRect(x: 0, y: 0, width: rect.width / 2, height: rect.height))
            croppedImages[1].draw(in: CGRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height))
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.9).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let locations: [CGFloat] = [0, 0.5, 1]
            if let ctx = UIGraphicsGetCurrentContext(), let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                let separatorLineRect = CGRect(x: (rect.width - separatorLineWidth) / 2, y: 0, width: separatorLineWidth, height: rect.height)
                let path = UIBezierPath(rect: separatorLineRect)
                path.addClip()
                let start = CGPoint(x: separatorLineRect.midX, y: separatorLineRect.minY)
                let end = CGPoint(x: separatorLineRect.midX, y: separatorLineRect.maxY)
                ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
            }
        } else if images.count == 3 {
            let croppedImages = [self.image(withImage: images[0], relativeRect: rectangleRect),
                                 self.image(withImage: images[1], relativeRect: squareRect),
                                 self.image(withImage: images[2], relativeRect: squareRect)]
            croppedImages[0].draw(in: CGRect(x: 0, y: 0, width: rect.width / 2, height: rect.height))
            croppedImages[1].draw(in: CGRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height / 2))
            croppedImages[2].draw(in: CGRect(x: rect.width / 2, y: rect.height / 2, width: rect.width / 2, height: rect.height / 2))
            let verticalColors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.9).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let verticalLocations: [CGFloat] = [0, 0.5, 1]
            let horizontalColors = [UIColor.white.withAlphaComponent(0.9).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let horizontalLocations: [CGFloat] = [0, 1]
            let colorsSpace = CGColorSpaceCreateDeviceRGB()
            if let ctx = UIGraphicsGetCurrentContext(), let verticalGradient = CGGradient(colorsSpace: colorsSpace, colors: verticalColors, locations: verticalLocations), let horizontalGradient = CGGradient(colorsSpace: colorsSpace, colors: horizontalColors, locations: horizontalLocations) {
                ctx.saveGState()
                let verticalLineRect = CGRect(x: (rect.width - separatorLineWidth) / 2, y: 0, width: separatorLineWidth, height: rect.height)
                let verticalLinePath = UIBezierPath(rect: verticalLineRect)
                verticalLinePath.addClip()
                let verticalStart = CGPoint(x: verticalLineRect.midX, y: verticalLineRect.minY)
                let verticalEnd = CGPoint(x: verticalLineRect.midX, y: verticalLineRect.maxY)
                ctx.drawLinearGradient(verticalGradient, start: verticalStart, end: verticalEnd, options: [])
                ctx.restoreGState()

                let horizontalLineRect = CGRect(x: rect.width / 2, y: (rect.height - separatorLineWidth) / 2, width: rect.width / 2, height: separatorLineWidth)
                let horizontalLinePath = UIBezierPath(rect: horizontalLineRect)
                horizontalLinePath.addClip()
                let horizontalStart = CGPoint(x: horizontalLineRect.minX, y: horizontalLineRect.midY)
                let horizontalEnd = CGPoint(x: horizontalLineRect.maxX, y: horizontalLineRect.midY)
                ctx.drawLinearGradient(horizontalGradient, start: horizontalStart, end: horizontalEnd, options: [])
            }
        } else if images.count >= 4 {
            let croppedImages = [self.image(withImage: images[0], relativeRect: squareRect),
                                 self.image(withImage: images[1], relativeRect: squareRect),
                                 self.image(withImage: images[2], relativeRect: squareRect),
                                 self.image(withImage: images[3], relativeRect: squareRect)]
            croppedImages[0].draw(in: CGRect(x: 0, y: 0, width: rect.width / 2, height: rect.height / 2))
            croppedImages[1].draw(in: CGRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height / 2))
            croppedImages[2].draw(in: CGRect(x: 0, y: rect.height / 2, width: rect.width / 2, height: rect.height / 2))
            croppedImages[3].draw(in: CGRect(x: rect.width / 2, y: rect.height / 2, width: rect.width / 2, height: rect.height / 2))
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.9).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let locations: [CGFloat] = [0, 0.5, 1]
            if let ctx = UIGraphicsGetCurrentContext(), let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                ctx.saveGState()
                let verticalLineRect = CGRect(x: (rect.width - separatorLineWidth) / 2, y: 0, width: separatorLineWidth, height: rect.height)
                let verticalLinePath = UIBezierPath(rect: verticalLineRect)
                verticalLinePath.addClip()
                let verticalStart = CGPoint(x: verticalLineRect.midX, y: verticalLineRect.minY)
                let verticalEnd = CGPoint(x: verticalLineRect.midX, y: verticalLineRect.maxY)
                ctx.drawLinearGradient(gradient, start: verticalStart, end: verticalEnd, options: [])
                ctx.restoreGState()

                let horizontalLineRect = CGRect(x: 0, y: (rect.height - separatorLineWidth) / 2, width: rect.width, height: separatorLineWidth)
                let horizontalLinePath = UIBezierPath(rect: horizontalLineRect)
                horizontalLinePath.addClip()
                let horizontalStart = CGPoint(x: horizontalLineRect.minX, y: horizontalLineRect.midY)
                let horizontalEnd = CGPoint(x: horizontalLineRect.maxX, y: horizontalLineRect.midY)
                ctx.drawLinearGradient(gradient, start: horizontalStart, end: horizontalEnd, options: [])
            }
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? #imageLiteral(resourceName: "ic_conversation_group")
    }

    private static func image(withImage source: UIImage, relativeRect rect: CGRect) -> UIImage {
        let absoluteRect = CGRect(x: rect.origin.x * source.size.width,
                                  y: rect.origin.y * source.size.height,
                                  width: rect.width * source.size.width,
                                  height: rect.height * source.size.height)
        return image(withImage: source, rect: absoluteRect)
    }

    private static func image(withImage source: UIImage, rect: CGRect) -> UIImage {
        guard let cgImage = source.cgImage else {
            return source
        }
        let croppingRect = CGRect(x: rect.origin.x * source.scale,
                                  y: rect.origin.y * source.scale,
                                  width: rect.width * source.scale,
                                  height: rect.height * source.scale)
        if let cropped = cgImage.cropping(to: croppingRect) {
            return UIImage(cgImage: cropped, scale: source.scale, orientation: source.imageOrientation)
        } else {
            return source
        }
    }

    private static func offset(forIndex index: Int, of count: Int) -> CGPoint {
        let offset: CGFloat = (1 - sqrt(2) / 2) / 4
        switch count {
        case 0, 1:
            return .zero
        case 2:
            switch index {
            case 0:
                return CGPoint(x: offset / 2, y: 0)
            default:
                return CGPoint(x: -offset / 2, y: 0)
            }
        case 3:
            switch index {
            case 0:
                return CGPoint(x: offset / 2, y: 0)
            case 1:
                return CGPoint(x: -offset, y: offset)
            default:
                return CGPoint(x: -offset, y: -offset)
            }
        default:
            switch index {
            case 0:
                return CGPoint(x: offset, y: offset)
            case 1:
                return CGPoint(x: -offset, y: offset)
            case 2:
                return CGPoint(x: offset, y: -offset)
            default:
                return CGPoint(x: -offset, y: -offset)
            }
        }
    }

}
