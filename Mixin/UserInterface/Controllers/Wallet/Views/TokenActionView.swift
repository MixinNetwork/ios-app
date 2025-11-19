import UIKit

final class TokenActionView: UIView {
    
    protocol Delegate: AnyObject {
        func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction)
    }
    
    var actions: [TokenAction] = [] {
        didSet {
            reloadActionButtons()
        }
    }
    
    var badgeActions: Set<TokenAction> = [] {
        didSet {
            reloadBadgeViews()
        }
    }
    
    weak var delegate: Delegate?
    
    private var buttons: [TokenAction: UIButton] = [:]
    private var badgeViews: [TokenAction: BadgeDotView] = [:]
    
    private weak var stackView: UIStackView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadStackView()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadStackView()
    }
    
    @objc private func performAction(_ button: UIButton) {
        guard let action = TokenAction(rawValue: button.tag) else {
            return
        }
        delegate?.tokenActionView(self, wantsToPerformAction: action)
    }
    
    private func loadStackView() {
        let stackView = UIStackView(frame: bounds)
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        addSubview(stackView)
        stackView.snp.makeEdgesEqualToSuperview()
        self.stackView = stackView
    }
    
    private func reloadActionButtons() {
        stackView.arrangedSubviews.forEach(stackView.removeArrangedSubview(_:))
        buttons.removeAll()
        for action in actions {
            let button = UIButton(type: .system)
            button.configuration = {
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 12, weight: .medium)
                    ),
                    .foregroundColor: R.color.text()!,
                ]
                let (image, title) = switch action {
                case .receive:
                    (R.image.token_action_receive(), R.string.localizable.receive())
                case .send:
                    (R.image.token_action_send(), R.string.localizable.caption_send())
                case .swap:
                    (R.image.token_action_swap(), R.string.localizable.trade())
                case .buy:
                    (R.image.token_action_buy(), R.string.localizable.buy())
                }
                var config: UIButton.Configuration = .plain()
                config.baseBackgroundColor = .clear
                config.imagePlacement = .top
                config.imagePadding = 8
                config.image = image
                config.attributedTitle = AttributedString(title, attributes: .init(textAttributes))
                return config
            }()
            button.tag = action.rawValue
            button.addTarget(self, action: #selector(performAction(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            buttons[action] = button
        }
    }
    
    private func reloadBadgeViews() {
        for action in badgeActions {
            guard
                let button = buttons[action],
                let imageView = button.imageView,
                badgeViews[action] == nil
            else {
                continue
            }
            let badgeView = BadgeDotView()
            badgeView.backgroundColor = R.color.background()
            addSubview(badgeView)
            badgeView.snp.makeConstraints { make in
                make.top.equalTo(imageView.snp.top)
                make.trailing.equalTo(imageView.snp.trailing)
            }
            badgeViews[action] = badgeView
        }
        for (action, badgeView) in badgeViews where !badgeActions.contains(action) {
            badgeView.removeFromSuperview()
        }
    }
    
}
