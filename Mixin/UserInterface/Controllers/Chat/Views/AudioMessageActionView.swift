import UIKit

class AudioMessageActionView: UIView {
    
    let operationButton = NetworkOperationButton()
    let playbackStateWrapperView = UIView()
    let backgroundImageView = UIImageView()
    let playbackStateImageView = UIImageView()
    
    init() {
        super.init(frame: .zero)
        backgroundImageView.image = R.image.ic_network_op_background_legacy()
        for imageView in [backgroundImageView, playbackStateImageView] {
            imageView.contentMode = .center
            playbackStateWrapperView.addSubview(imageView)
        }
        [operationButton, playbackStateWrapperView].forEach(addSubview(_:))
        for view in [operationButton, backgroundImageView, playbackStateImageView, playbackStateWrapperView] {
            view.snp.makeEdgesEqualToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
