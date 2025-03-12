import UIKit

final class TokenActionView: UIView {
    
    protocol Delegate: AnyObject {
        func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction)
    }
    
    var swapButton: UIButton {
        buttons[TokenAction.swap.rawValue]
    }
    
    var badgeOnSwap = false {
        didSet {
            if badgeOnSwap {
                showBadgeViewOnSwapButton()
            } else {
                badgeView?.removeFromSuperview()
                badgeView = nil
            }
        }
    }
    
    weak var delegate: Delegate?
    
    private var buttons: [UIButton] = []
    
    private weak var badgeView: BadgeDotView?
    
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
            stackView.addArrangedSubview(button)
            buttons.append(button)
        }
    }
    
    private func showBadgeViewOnSwapButton() {
        guard
            badgeView == nil,
            !swapButton.isHidden,
            let imageView = swapButton.imageView
        else {
            return
        }
        let badgeView = BadgeDotView()
        badgeView.backgroundColor = R.color.background()
        addSubview(badgeView)
        badgeView.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.top)
            make.trailing.equalTo(imageView.snp.trailing)
        }
        self.badgeView = badgeView
    }
    
}
