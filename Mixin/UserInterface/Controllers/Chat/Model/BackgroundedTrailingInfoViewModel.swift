import UIKit

protocol BackgroundedTrailingInfoViewModel: class {
    
    var trailingInfoBackgroundFrame: CGRect { get set }
    
    func layoutTrailingInfoBackgroundFrame()
    
}

extension BackgroundedTrailingInfoViewModel where Self: DetailInfoMessageViewModel {
    
    func layoutTrailingInfoBackgroundFrame() {
        let margin: CGFloat = 10
        let x = (isEncrypted ? encryptedIconFrame.minX : timeFrame.minX) - margin / 2
        let y = timeFrame.origin.y + (timeFrame.height - TrailingInfoBackgroundView.height) / 2
        let width: CGFloat = {
            let encryptedIconWidthIfHas = isEncrypted ? (encryptedIconFrame.width + Self.encryptedIconRightMargin) : 0
            let statusIconWidthIfHas = showStatusImage ? (statusFrame.width + Self.statusLeftMargin) : 0
            return encryptedIconWidthIfHas + timeFrame.width + statusIconWidthIfHas + margin
        }()
        trailingInfoBackgroundFrame = CGRect(x: x, y: y, width: width, height: TrailingInfoBackgroundView.height)
    }
    
}
