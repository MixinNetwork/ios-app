import Foundation
import SDWebImage

struct GroupIconMaker {
    
    enum Avatar {
        case image(UIImage)
        case generated(background: UIImage, name: String)
    }
    
    enum ImageRelativeRect {
        static let binary = CGRect(x: CGFloat(1) / 4, y: 0, width: 1/2, height: 1)
        static let ternary = CGRect(x: CGFloat(1) / 3, y: 0, width: 1/3, height: 1)
    }
    
    static func make(participants: [ParticipantUser]) -> UIImage? {
        var avatars = [Avatar]()
        let semaphore = DispatchSemaphore(value: 0)
        for participant in participants {
            if !participant.userAvatarUrl.isEmpty, let url = URL(string: participant.userAvatarUrl) {
                SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil, completed: { (image, _, error, _, _, _) in
                    if let image = image {
                        avatars.append(.image(image))
                    }
                    semaphore.signal()
                })
                semaphore.wait()
            } else {
                let colorIndex = participant.userId.positiveHashCode() % 24 + 1
                if let background = UIImage(named: "AvatarBackground/color\(colorIndex)"), let firstLetter = participant.userFullName.first {
                    let name = String([firstLetter]).uppercased()
                    avatars.append(.generated(background: background, name: name))
                }
            }
            if avatars.count == 3 {
                break
            }
        }
        
        guard !avatars.isEmpty else {
            return nil
        }
        let fragments = avatars.enumerated().map { (index, avatar) -> UIImage in
            switch avatar {
            case let .image(image):
                switch avatars.count {
                case 1:
                    return image
                case 2:
                    return self.image(withImage: image, relativeRect: ImageRelativeRect.binary)
                default:
                    return self.image(withImage: image, relativeRect: ImageRelativeRect.ternary)
                }
            case let .generated(background, name):
                switch avatars.count {
                case 1:
                    return draw(text: name, fontSize: 17, on: background)
                case 2:
                    let rect = relativeRect(index: index, numberOfPieces: avatars.count)
                    let background = self.image(withImage: background, relativeRect: rect)
                    return draw(text: name, fontSize: 15, on: background)
                default:
                    let rect = relativeRect(index: index, numberOfPieces: avatars.count)
                    let background = self.image(withImage: background, relativeRect: rect)
                    return draw(text: name, fontSize: 12, on: background)
                }
            }
        }
        
        guard fragments.count > 1 else {
            return fragments[0]
        }
        let canvasSize = CGSize(width: 512, height: 512)
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let fragmentSize = CGSize(width: canvasSize.width / CGFloat(fragments.count), height: canvasSize.height)
        let separatorLineSize = CGSize(width: 4 * UIScreen.main.scale, height: canvasSize.height)
        let colors = [UIColor.white.withAlphaComponent(0).cgColor,
                      UIColor.white.withAlphaComponent(0.9).cgColor,
                      UIColor.white.withAlphaComponent(0).cgColor] as CFArray
        let locations: [CGFloat] = [0, 0.5, 1]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)
        UIGraphicsBeginImageContext(canvasSize)
        UIBezierPath(roundedRect: canvasRect, cornerRadius: canvasSize.width / 2).addClip()
        
        func drawLine(in rect: CGRect) {
            guard let ctx = UIGraphicsGetCurrentContext(), let gradient = gradient else {
                return
            }
            let path = UIBezierPath(rect: rect)
            path.addClip()
            let start = CGPoint(x: rect.midX, y: rect.minY)
            let end = CGPoint(x: rect.midX, y: rect.maxY)
            ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
        }
        
        if fragments.count == 2 {
            let fragmentOrigins = [CGPoint(x: 0, y: 0),
                                   CGPoint(x: fragmentSize.width, y: 0)]
            fragments[0].draw(in: CGRect(origin: fragmentOrigins[0], size: fragmentSize))
            fragments[1].draw(in: CGRect(origin: fragmentOrigins[1], size: fragmentSize))
            let separatorOrigin = CGPoint(x: (canvasSize.width - separatorLineSize.width) / 2, y: 0)
            let rect = CGRect(origin: separatorOrigin, size: separatorLineSize)
            drawLine(in: rect)
        } else {
            let fragmentOrigins = [CGPoint(x: 0, y: 0),
                                   CGPoint(x: fragmentSize.width, y: 0),
                                   CGPoint(x: fragmentSize.width * 2, y: 0)]
            fragments[0].draw(in: CGRect(origin: fragmentOrigins[0], size: fragmentSize))
            fragments[1].draw(in: CGRect(origin: fragmentOrigins[1], size: fragmentSize))
            fragments[2].draw(in: CGRect(origin: fragmentOrigins[2], size: fragmentSize))
            if let ctx = UIGraphicsGetCurrentContext() {
                ctx.saveGState()
                let origin1 = CGPoint(x: fragmentOrigins[1].x - separatorLineSize.width, y: 0)
                let rect1 = CGRect(origin: origin1, size: separatorLineSize)
                drawLine(in: rect1)
                ctx.restoreGState()
                
                let origin2 = CGPoint(x: fragmentOrigins[2].x - separatorLineSize.width, y: 0)
                let rect2 = CGRect(origin: origin2, size: separatorLineSize)
                drawLine(in: rect2)
            }
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
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
    
    private static func draw(text: String, fontSize: CGFloat, on image: UIImage) -> UIImage {
        guard !text.isEmpty else {
            return image
        }
        let targetWidth = image.size.width
        let targetHeight = image.size.height
        let textColor = UIColor.white
        let textFont = UIFont.systemFont(ofSize: fontSize)
        let textFontAttributes = [NSAttributedString.Key.font: textFont,
                                  NSAttributedString.Key.foregroundColor: textColor]
        let string = text as NSString
        let stringSize = string.size(withAttributes: textFontAttributes)
        let textRect = CGRect(x: (targetWidth - stringSize.width) / 2,
                              y: (targetHeight - stringSize.height) / 2,
                              width: stringSize.width,
                              height: stringSize.height)
        UIGraphicsBeginImageContextWithOptions(image.size, false, UIScreen.main.scale)
        image.draw(in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        string.draw(in: textRect, withAttributes: textFontAttributes)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }
        return newImage
    }
    
    private static func relativeRect(index: Int, numberOfPieces: Int) -> CGRect {
        switch numberOfPieces {
        case 1:
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        case 2:
            switch index {
            case 0:
                return CGRect(x: 0, y: 0, width: 0.5, height: 1)
            default:
                return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
            }
        default:
            let width: CGFloat = 1 / 3
            switch index {
            case 0:
                return CGRect(x: 0, y: 0, width: width, height: 1)
            case 1:
                return CGRect(x: width, y: 0, width: width, height: 1)
            default:
                return CGRect(x: width * 2, y: 0, width: width, height: 1)
            }
        }
    }
    
}
