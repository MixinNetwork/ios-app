import UIKit

final class DecimalButton: UIControl {
    
    @IBInspectable var value: UInt8 = 0 {
        didSet {
            button.setTitle(String(value), for: .normal)
        }
    }
    
    private let button = HighlightableButton(type: .custom)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadButton()
    }
    
    @objc private func sendTouchDown(_ sender: Any) {
        sendActions(for: .touchDown)
    }
    
    @objc private func sendTouchUpInside(_ sender: Any) {
        sendActions(for: .touchUpInside)
    }
    
    private func loadButton() {
        addSubview(button)
        button.snp.makeEdgesEqualToSuperview()
        button.setTitleColor(.text, for: .normal)
        if let label = button.titleLabel {
            label.font = .systemFont(ofSize: 25, weight: .medium)
        }
        button.normalColor = .clear
        button.highlightedColor = .secondaryBackground
        button.clipsToBounds = true
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(sendTouchUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(sendTouchDown(_:)), for: .touchDown)
    }
    
}
