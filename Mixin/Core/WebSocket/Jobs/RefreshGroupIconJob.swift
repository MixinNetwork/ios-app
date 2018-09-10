import Foundation
import UIKit
import SDWebImage
import Bugsnag

class RefreshGroupIconJob: AsynchronousJob {

    let conversationId: String

    private let rect = CGRect(x: 0, y: 0, width: 256, height: 256)
    private let squareRect = CGRect(x: 7.0/34.0, y: 7.0/34.0, width: 20.0/34.0, height: 20.0/34.0)
    private let rectangleRect = CGRect(x: 13.0/46.0, y: 3.0/46.0, width: 20.0/46.0, height: 40.0/46.0)
    private let separatorLineWidth: CGFloat = 2 * UIScreen.main.scale
    
    init(conversationId: String) {
        self.conversationId = conversationId
    }

    override func getJobId() -> String {
        return "refresh-group-icon-\(conversationId)"
    }

    override func execute() -> Bool {
        let participants = ParticipantDAO.shared.getGroupIconParticipants(conversationId: conversationId)
        let participantIds: [String] = participants.flatMap { $0.userAvatarUrl.isEmpty ? String([$0.userFullName.first ?? Character(" ")]) : $0.userAvatarUrl }
        let imageFile = conversationId + "-" + participantIds.joined().md5() + ".png"
        let imageUrl = MixinFile.groupIconsUrl.appendingPathComponent(imageFile)
        guard !FileManager.default.fileExists(atPath: imageUrl.path) else {
            RefreshGroupIconJob.updateAndRemoveOld(conversationId: conversationId, imageFile: imageFile)
            return false
        }

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
                    if error == nil, let image = image {
                        images.append(image)
                        isSucceed = true
                    }
                    semaphore.signal()
                })
                semaphore.wait()
                if !isSucceed {
                    return false
                }
            } else {
                let colorIndex = participant.userIdentityNumber.integerValue % 24 + 1
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
        
        if !images.isEmpty {
            do {
                let groupImage = images.count == 1 ? images[0] : puzzleImages(images: images)
                try? FileManager.default.removeItem(atPath: imageUrl.path)
                if let data = UIImagePNGRepresentation(groupImage) {
                    try data.write(to: imageUrl)
                    RefreshGroupIconJob.updateAndRemoveOld(conversationId: conversationId, imageFile: imageFile)
                }
            } catch {
                Bugsnag.notifyError(error)
            }
        }

        finishJob()

        return true
    }
    
    private func fontSize(forText text: String, size greatestSize: CGSize) -> CGFloat {
        let maxFontSize = 17
        let minFontSize = 12
        let nsText = text as NSString
        for i in minFontSize...maxFontSize {
            let attributes = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: CGFloat(i))]
            let size = nsText.boundingRect(with: UILayoutFittingCompressedSize, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            if size.width > greatestSize.width || size.height > greatestSize.height {
                return CGFloat(i - 1)
            }
        }
        return CGFloat(maxFontSize)
    }

    private static func updateAndRemoveOld(conversationId: String, imageFile: String) {
        let oldIconUrl = ConversationDAO.shared.getConversationIconUrl(conversationId: conversationId)
        ConversationDAO.shared.updateIconUrl(conversationId: conversationId, iconUrl: imageFile)
        if let removeIconUrl = oldIconUrl, !removeIconUrl.isEmpty, removeIconUrl != imageFile {
            try? FileManager.default.removeItem(atPath: MixinFile.groupIconsUrl.appendingPathComponent(removeIconUrl).path)
        }
        let change = ConversationChange(conversationId: conversationId, action: .updateGroupIcon(iconUrl: imageFile))
        NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: change)
    }

}

extension RefreshGroupIconJob {

    private func puzzleImages(images: [UIImage]) -> UIImage {
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

    private func image(withImage source: UIImage, relativeRect rect: CGRect) -> UIImage {
        let absoluteRect = CGRect(x: rect.origin.x * source.size.width,
                                  y: rect.origin.y * source.size.height,
                                  width: rect.width * source.size.width,
                                  height: rect.height * source.size.height)
        return image(withImage: source, rect: absoluteRect)
    }
    
    private func image(withImage source: UIImage, rect: CGRect) -> UIImage {
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
    
    private func offset(forIndex index: Int, of count: Int) -> CGPoint {
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
