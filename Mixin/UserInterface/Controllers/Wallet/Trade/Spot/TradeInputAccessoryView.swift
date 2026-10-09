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
    private let bottomInset: CGFloat = {
        if #available(iOS 26, *) {
            8
        } else {
            0
        }
    }()
    
    private weak var containerView: UIView!
    private weak var itemStackView: UIStackView!
    
    private var backgroundViews: [UIView] = []
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44 + bottomInset)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 26, *) {
            containerView.layer.cornerRadius = containerView.frame.height / 2
        }
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
        for view in backgroundViews {
            view.removeFromSuperview()
        }
        backgroundViews = []
        
        for (index, item) in items.enumerated() {
            let config = buttonConfiguration(title: item.title)
            let itemButton = UIButton(configuration: config)
            itemButton.tag = index
            itemButton.addTarget(self, action: #selector(reportItem(_:)), for: .touchUpInside)
            itemStackView.addArrangedSubview(itemButton)
            
            let backgroundView = UIView()
            backgroundView.backgroundColor = R.color.background()
            backgroundView.isUserInteractionEnabled = false
            backgroundView.layer.cornerRadius = buttonBackgroundHeight / 2
            backgroundView.layer.masksToBounds = true
            containerView.insertSubview(backgroundView, belowSubview: itemStackView)
            backgroundView.snp.makeConstraints { make in
                make.leading.trailing.centerY.equalTo(itemButton)
                make.height.equalTo(buttonBackgroundHeight)
            }
            backgroundViews.append(backgroundView)
        }
    }
    
    private func loadSubviews() {
        let containerView = UIView()
        self.containerView = containerView
        if #available(iOS 26, *) {
            backgroundColor = .clear
            containerView.backgroundColor = R.color.keyboard_background_14()!
            containerView.layer.cornerRadius = 22
            containerView.layer.masksToBounds = true
            addSubview(containerView)
            containerView.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.bottom.equalToSuperview().offset(-bottomInset)
                make.leading.equalToSuperview().offset(8)
                make.trailing.equalToSuperview().offset(-8)
            }
        } else {
            backgroundColor = R.color.keyboard_background_14()
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
            make.top.bottom.equalToSuperview()
            make.height.equalTo(44)
            make.leading.equalToSuperview().offset(12)
        }
        itemStackView = stackView
        
        var doneButtonConfig = buttonConfiguration(title: R.string.localizable.done())
        doneButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
        let doneButton = UIButton(configuration: doneButtonConfig)
        doneButton.addTarget(self, action: #selector(reportDone(_:)), for: .touchUpInside)
        doneButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        doneButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        containerView.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.leading.equalTo(stackView.snp.trailing)
            make.top.bottom.equalToSuperview()
            make.trailing.equalToSuperview().offset(-6)
        }
    }
    
    private func buttonConfiguration(title: String) -> UIButton.Configuration {
        var config: UIButton.Configuration = .plain()
        config.titleTextAttributesTransformer = .init { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 14)
            )
            outgoing.foregroundColor = R.color.text()
            return outgoing
        }
        config.title = title
        return config
    }
    
}
