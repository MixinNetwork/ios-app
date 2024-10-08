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
        
        for (index, item) in items.enumerated() {
            let button = buttons[index]
            if #available(iOS 15.0, *) {
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
            } else {
                button.setImage(item.image, for: .normal)
                button.setImage(item.selectedImage, for: .selected)
                button.setImage(item.selectedImage, for: [.highlighted, .selected])
            }
            button.tag = index
            button.isSelected = false
        }
        
        selectedIndex = nil
    }
    
}
