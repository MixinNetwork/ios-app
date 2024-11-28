import UIKit

final class TokenActionView: UIView {
    
    protocol Delegate: AnyObject {
        func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction)
    }
    
    weak var delegate: Delegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSubviews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    @objc private func performAction(_ button: UIButton) {
        guard let action = TokenAction(rawValue: button.tag) else {
            return
        }
        delegate?.tokenActionView(self, wantsToPerformAction: action)
    }
    
    private func loadSubviews() {
        let stackView = UIStackView(frame: bounds)
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        addSubview(stackView)
        stackView.snp.makeEdgesEqualToSuperview()
        
        for (index, action) in TokenAction.allCases.enumerated() {
            let button = UIButton(type: .system)
            if #available(iOS 15.0, *) {
                button.configuration = {
                    let textAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                        .foregroundColor: R.color.text()!,
                    ]
                    let (image, title) = switch action {
                    case .receive:
                        (R.image.token_action_receive(), R.string.localizable.receive())
                    case .send:
                        (R.image.token_action_send(), R.string.localizable.caption_send())
                    case .swap:
                        (R.image.token_action_swap(), R.string.localizable.swap())
                    }
                    var config: UIButton.Configuration = .plain()
                    config.baseBackgroundColor = .clear
                    config.imagePlacement = .top
                    config.imagePadding = 8
                    config.image = image
                    config.attributedTitle = AttributedString(title, attributes: .init(textAttributes))
                    return config
                }()
                button.tag = index
                button.addTarget(self, action: #selector(performAction(_:)), for: .touchUpInside)
            }
            stackView.addArrangedSubview(button)
        }
    }
    
}
