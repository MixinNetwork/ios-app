import UIKit

final class TradeInputAccessoryView: UIView {
    
    struct Item {
        let title: String
        let handler: (() -> Void)
    }
    
    var items: [Item] = [] {
        didSet {
            reload(items: items)
        }
    }
    
    var onDone: (() -> Void)?
    
    private let buttonBackgroundHeight: CGFloat = 32
    private let verticalInset: CGFloat = {
        if #available(iOS 26, *) {
            4
        } else {
            0
        }
    }()
    private let bottomSpacing: CGFloat = {
        if #available(iOS 26, *) {
            8
        } else {
            0
        }
    }()
    
    private weak var itemStackView: UIStackView!
    
    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: 44 + verticalInset * 2 + bottomSpacing
        )
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    @objc private func reportItem(_ sender: UIButton) {
        items[sender.tag].handler()
    }
    
    @objc private func reportDone(_ sender: Any) {
        onDone?()
    }
    
    private func reload(items: [Item]) {
        for view in itemStackView.subviews {
            view.removeFromSuperview()
        }
        
        for (index, item) in items.enumerated() {
            var config: UIButton.Configuration = .filled()
            config.attributedTitle = AttributedString(
                string: item.title,
                scalingByFontSize: 14,
            )
            config.baseForegroundColor = R.color.text()
            config.background.backgroundColor = R.color.background()
            config.background.cornerRadius = buttonBackgroundHeight / 2
            let backgroundInset = (44 - buttonBackgroundHeight) / 2
            config.background.backgroundInsets = NSDirectionalEdgeInsets(
                top: backgroundInset,
                leading: 0,
                bottom: backgroundInset,
                trailing: 0,
            )
            let itemButton = UIButton(configuration: config)
            itemButton.tag = index
            itemButton.addTarget(self, action: #selector(reportItem(_:)), for: .touchUpInside)
            itemStackView.addArrangedSubview(itemButton)
        }
    }
    
    private func loadSubviews() {
        autoresizingMask = .flexibleHeight
        let containerView: UIView
        if #available(iOS 26, *) {
            backgroundColor = .clear
            let effect = UIGlassEffect()
            effect.tintColor = R.color.background_secondary()
            let effectView = UIVisualEffectView(effect: effect)
            effectView.cornerConfiguration = .capsule()
            addSubview(effectView)
            effectView.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.bottom.equalToSuperview().offset(-bottomSpacing)
                make.leading.equalToSuperview().offset(8)
                make.trailing.equalToSuperview().offset(-8)
            }
            containerView = effectView.contentView
        } else {
            backgroundColor = R.color.keyboard_background_14()
            containerView = UIView()
            addSubview(containerView)
            containerView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.spacing = 10
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        containerView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(verticalInset)
            make.bottom.equalToSuperview().offset(-verticalInset)
            make.height.equalTo(44)
            make.leading.equalToSuperview().offset(12)
        }
        itemStackView = stackView
        
        var doneButtonConfig: UIButton.Configuration = .plain()
        doneButtonConfig.attributedTitle = AttributedString(
            string: R.string.localizable.done(),
            scalingByFontSize: 14,
        )
        doneButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
        doneButtonConfig.background = .clear()
        doneButtonConfig.baseForegroundColor = R.color.text()
        let doneButton = UIButton(configuration: doneButtonConfig)
        doneButton.addTarget(self, action: #selector(reportDone(_:)), for: .touchUpInside)
        doneButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        doneButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        containerView.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.leading.equalTo(stackView.snp.trailing)
            make.top.bottom.equalTo(stackView)
            make.trailing.equalToSuperview().offset(-6)
        }
    }
    
}
