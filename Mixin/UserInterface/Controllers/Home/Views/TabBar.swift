import UIKit

protocol TabBarDelegate: AnyObject {
    // called when a new view is selected by the user (but not programmatically)
    func tabBar(_ tabBar: TabBar, didSelect item: TabBar.Item)
}

final class TabBar: UIView {
    
    struct Item {
        let id: Int
        let image: UIImage
        let selectedImage: UIImage
        let text: String
        var badge: Bool
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.layoutFittingExpandedSize.width,
               height: contentHeight + safeAreaInsets.bottom)
    }
    
    weak var delegate: TabBarDelegate?
    
    var items: [Item] = [] {
        didSet {
            reloadButtons()
        }
    }
    
    var selectedIndex: Int? {
        didSet {
            if let previousSelection = oldValue {
                buttons[previousSelection].isSelected = false
            }
            if let selection = selectedIndex {
                buttons[selection].isSelected = true
            }
        }
    }
    
    private let stackView = UIStackView()
    private let contentHeight: CGFloat = 48
    private let horizontalMargin: CGFloat = 20
    
    private var buttons: [UIButton] = []
    private var badgeViews: [UIView] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        invalidateIntrinsicContentSize()
    }
    
    @objc private func switchTab(_ sender: UIButton) {
        let item = items[sender.tag]
        selectedIndex = sender.tag
        delegate?.tabBar(self, didSelect: item)
    }
    
    private func loadSubviews() {
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(horizontalMargin)
            make.trailing.equalToSuperview().offset(-horizontalMargin)
            make.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(contentHeight)
        }
    }
    
    private func reloadButtons() {
        let numberOfButtonsToBeAdded = items.count - buttons.count
        if numberOfButtonsToBeAdded > 0 {
            for _ in 0..<numberOfButtonsToBeAdded {
                let button = UIButton(type: .custom)
                button.addTarget(self, action: #selector(switchTab(_:)), for: .touchUpInside)
                let wrapper = UIView()
                wrapper.backgroundColor = .clear
                wrapper.addSubview(button)
                stackView.addArrangedSubview(wrapper)
                buttons.append(button)
                button.snp.makeConstraints { make in
                    make.width.greaterThanOrEqualTo(60)
                    make.top.bottom.centerX.equalToSuperview()
                }
            }
        } else if numberOfButtonsToBeAdded < 0 {
            for button in stackView.arrangedSubviews.suffix(-numberOfButtonsToBeAdded) {
                button.removeFromSuperview()
            }
            buttons.removeLast(-numberOfButtonsToBeAdded)
        }
        
        for badgeView in badgeViews {
            badgeView.removeFromSuperview()
        }
        badgeViews.removeAll()
        
        for (index, item) in items.enumerated() {
            let button = buttons[index]
            button.configurationUpdateHandler = { button in
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: R.color.text()!,
                ]
                var config: UIButton.Configuration = .plain()
                config.baseBackgroundColor = .clear
                config.imagePlacement = .top
                config.imagePadding = 3
                if button.state.contains(.selected) {
                    config.image = item.selectedImage
                    config.attributedTitle = AttributedString(item.text, attributes: .init(textAttributes))
                } else {
                    config.image = item.image
                    config.attributedTitle = AttributedString(item.text, attributes: .init(textAttributes))
                }
                button.configuration = config
            }
            button.tag = index
            button.isSelected = index == selectedIndex
            
            if item.badge {
                let badge = UIView()
                badge.backgroundColor = R.color.error_red()
                badge.layer.cornerRadius = 4
                badge.layer.masksToBounds = true
                addSubview(badge)
                badgeViews.append(badge)
                badge.snp.makeConstraints { make in
                    make.width.height.equalTo(8)
                    make.top.equalToSuperview().offset(4)
                    make.leading.equalTo(button.snp.centerX).offset(12)
                }
            }
        }
    }
    
}
