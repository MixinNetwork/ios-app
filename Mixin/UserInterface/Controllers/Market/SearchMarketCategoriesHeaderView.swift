import UIKit

final class SearchMarketCategoriesHeaderView: UICollectionReusableView {
    
    static let reuseIdentifier = "SearchMarketCategoriesHeader"
    
    var titles: [String] = [] {
        didSet {
            guard titles != oldValue else {
                return
            }
            reloadButtons(titles: titles)
        }
    }
    
    var onSelect: ((Int) -> Void)?
    
    private let stackView = UIStackView()
    
    private var buttons: [ConfigurationBasedOutlineButton] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadStackView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadStackView()
    }
    
    func selectButton(at selectedIndex: Int) {
        for (index, button) in buttons.enumerated() {
            button.isSelected = (index == selectedIndex)
        }
    }
    
    @objc private func reportSelectionChange(_ sender: UIButton) {
        for button in buttons {
            button.isSelected = (button == sender)
        }
        onSelect?(sender.tag)
    }
    
    private func reloadButtons(titles: [String]) {
        for button in buttons {
            button.removeFromSuperview()
        }
        buttons = []
        for (index, title) in titles.enumerated() {
            var config: UIButton.Configuration = .bordered()
            config.cornerStyle = .capsule
            config.attributedTitle = AttributedString(string: title, scalingByFontSize: 14)
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
            let button = ConfigurationBasedOutlineButton(configuration: config)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.tag = index
            button.addTarget(self, action: #selector(reportSelectionChange(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            buttons.append(button)
        }
    }
    
    private func loadStackView() {
        backgroundColor = R.color.background()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .fill
        stackView.distribution = .fill
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20).priority(999)
            make.top.bottom.equalToSuperview()
        }
    }
    
}
