import UIKit

final class StyledButton: BusyButton {
    
    enum Style {
        case filled
        case tinted
        case outline
        case plain
    }
    
    override var isEnabled: Bool {
        didSet {
            updateAppearance(style: style, isEnabled: isEnabled)
        }
    }
    
    var style: Style = .plain {
        didSet {
            updateAppearance(style: style, isEnabled: isEnabled)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.masksToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        layer.masksToBounds = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
    
    func applyDefaultContentInsets() {
        contentEdgeInsets = UIEdgeInsets(top: 14, left: 0, bottom: 15, right: 0)
    }
    
    private func updateAppearance(style: Style, isEnabled: Bool) {
        switch style {
        case .filled:
            busyIndicator.tintColor = .white
            if isEnabled {
                backgroundColor = R.color.background_tinted()
            } else {
                backgroundColor = R.color.button_background_disabled()
            }
            setTitleColor(.white, for: .normal)
            layer.borderWidth = 0
        case .tinted:
            busyIndicator.tintColor = R.color.theme()!
            if isEnabled {
                backgroundColor = R.color.background_quaternary()
            } else {
                backgroundColor = R.color.button_background_disabled()
            }
            setTitleColor(R.color.theme()!, for: .normal)
            layer.borderWidth = 0
        case .outline:
            backgroundColor = .clear
            if isEnabled {
                busyIndicator.tintColor = R.color.background_tinted()!
                setTitleColor(R.color.background_tinted()!, for: .normal)
                layer.borderColor = R.color.background_tinted()!.cgColor
            } else {
                busyIndicator.tintColor = R.color.button_background_disabled()!
                setTitleColor(R.color.button_background_disabled()!, for: .normal)
                layer.borderColor = R.color.button_background_disabled()!.cgColor
            }
            layer.borderWidth = 1
        case .plain:
            backgroundColor = .clear
            busyIndicator.tintColor = R.color.text_tertiary()!
            setTitleColor(R.color.theme()!, for: .normal)
            layer.borderWidth = 0
        }
    }
    
}
