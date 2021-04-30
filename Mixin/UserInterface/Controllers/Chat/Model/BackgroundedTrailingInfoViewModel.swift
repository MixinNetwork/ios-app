import UIKit

protocol BackgroundedTrailingInfoViewModel: AnyObject {
    
    var trailingInfoBackgroundFrame: CGRect { get set }
    
    func layoutTrailingInfoBackgroundFrame()
    
}

extension BackgroundedTrailingInfoViewModel where Self: DetailInfoMessageViewModel {
    
    func layoutTrailingInfoBackgroundFrame() {
        let margin: CGFloat = 10
        let minX: CGFloat
        if style.contains(.forwardedByBot) {
            minX = forwarderFrame.minX
        } else if isEncrypted {
            minX = encryptedIconFrame.minX
        } else {
            minX = timeFrame.minX
        }
        let x = minX - margin / 2
        let y = timeFrame.origin.y + (timeFrame.height - TrailingInfoBackgroundView.height) / 2
        let width: CGFloat = {
            let forwarderIconWidthIfHas = style.contains(.forwardedByBot) ? (forwarderFrame.width + Self.forwarderIconRightMargin) : 0
            let encryptedIconWidthIfHas = isEncrypted ? (encryptedIconFrame.width + Self.encryptedIconRightMargin) : 0
            let statusIconWidthIfHas = showStatusImage ? (statusFrame.width + Self.statusLeftMargin) : 0
            return forwarderIconWidthIfHas
                + encryptedIconWidthIfHas
                + timeFrame.width
                + statusIconWidthIfHas
                + margin
        }()
        trailingInfoBackgroundFrame = CGRect(x: x, y: y, width: width, height: TrailingInfoBackgroundView.height)
    }
    
}
