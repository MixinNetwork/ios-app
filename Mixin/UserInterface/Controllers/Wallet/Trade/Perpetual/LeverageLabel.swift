import UIKit
import MixinServices

final class LeverageLabel: InsetLabel {
    
    enum Color {
        case long
        case short
        case neutral
    }
    
    override var textColor: UIColor! {
        willSet {
            color = nil
        }
    }
    
    var color: Color? {
        didSet {
            updateColors()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    private func initialize() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateColors),
            name: AppGroupUserDefaults.User.marketColorAppearanceDidChangeNotification,
            object: nil
        )
        contentInset = UIEdgeInsets(top: 2, left: 3, bottom: 0, right: 3)
        layer.cornerRadius = 4
        layer.masksToBounds = true
        setFont(
            scaledFor: .condensed(size: 12),
            adjustForContentSize: true
        )
    }
    
    @objc private func updateColors() {
        switch color {
        case .long:
            let color = MarketColor.rising.uiColor
            super.backgroundColor = color.withAlphaComponent(0.1)
            super.textColor = color
        case .short:
            let color = MarketColor.falling.uiColor
            super.backgroundColor = color.withAlphaComponent(0.1)
            super.textColor = color
        case .neutral:
            super.backgroundColor = R.color.background_quaternary()
            super.textColor = R.color.text_tertiary()
        case nil:
            break
        }
    }
    
}
