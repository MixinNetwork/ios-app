import UIKit
import MixinServices
import MapKit

class LocationMessageViewModel: ImageMessageViewModel {
    
    typealias Snapshot = (image: UIImage, annotationCenter: CGPoint)
    
    let hasAddress: Bool
    
    override var statusNormalTintColor: UIColor {
        hasAddress ? .accessoryText : .white
    }
    
    override var trailingInfoColor: UIColor {
        hasAddress ? .accessoryText : .white
    }
    
    var cachedSnapshot: [UserInterfaceStyle: Snapshot] = [:]
    var informationFrame: CGRect?
    var labelsLeadingConstant: CGFloat = 20
    var maskFrame: CGRect = .zero
    
    private var bubbleWidth: CGFloat {
        ScreenWidth.current <= .short ? 260 : 296
    }
    
    override init(message: MessageItem) {
        hasAddress = message.location?.address != nil
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        let photoWidth: CGFloat
        if quotedMessageViewModel == nil {
            photoWidth = bubbleWidth
        } else {
            photoWidth = bubbleWidth - Self.quotingMessageMargin.horizontal
        }
        photoFrame.size = CGSize(width: photoWidth, height: 180)
        super.layout(width: width, style: style)
        if style.contains(.received) {
            labelsLeadingConstant = 20 - (quotedMessageViewModel == nil ? 0 : Self.quotingMessageMargin.trailing)
        } else {
            labelsLeadingConstant = 14
        }
        if hasAddress {
            photoFrame.size.height = 120
            let informationHeight: CGFloat = 60
            if quotedMessageViewModel == nil {
                maskFrame = photoFrame
                informationFrame = CGRect(x: photoFrame.origin.x,
                                          y: photoFrame.maxY,
                                          width: photoFrame.width,
                                          height: informationHeight)
            } else {
                maskFrame = CGRect(origin: photoFrame.origin,
                                   size: CGSize(width: photoFrame.width, height: photoFrame.height + informationHeight))
                informationFrame = CGRect(x: 0,
                                          y: photoFrame.height,
                                          width: photoFrame.width,
                                          height: informationHeight)
                photoFrame.origin = .zero
            }
        } else {
            photoFrame.size.height = 180
            maskFrame = photoFrame
            informationFrame = nil
            if quotedMessageViewModel != nil {
                photoFrame.origin = .zero
            }
        }
        layoutTrailingInfoBackgroundFrame()
    }
    
}
