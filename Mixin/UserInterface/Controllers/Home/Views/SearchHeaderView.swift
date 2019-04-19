import UIKit

class SearchHeaderView: UITableViewHeaderFooterView {
    
    static func height(isFirstSection: Bool) -> CGFloat {
        return isFirstSection ? 36 : 46
    }
    
    let label = UILabel()
    let button = UIButton(type: .system)
    let normalBackgroundView = UIView()
    let topShadowView = TopShadowView()
    
    lazy var topFillingBackgroundView: InfiniteTopView = {
        let view = InfiniteTopView()
        view.backgroundColor = .white
        return view
    }()
    
    var isFirstSection = false {
        didSet {
            layout(isFirstSection: isFirstSection)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    private func prepare() {
        normalBackgroundView.backgroundColor = .white
        backgroundView = normalBackgroundView
        clipsToBounds = false
        topShadowView.clipsToBounds = true
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.font = .systemFont(ofSize: 14)
        label.textColor = .darkText
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        button.setTitle(R.string.localizable.action_more(), for: .normal)
        button.setTitleColor(.highlightedText, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        contentView.addSubview(topShadowView)
        contentView.addSubview(label)
        contentView.addSubview(button)
        topShadowView.snp.makeConstraints { (make) in
            make.height.equalTo(10)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(contentView.snp.top)
        }
        label.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview().offset(-10)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(button.snp.leading).offset(-20)
        }
        button.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview().offset(-10 + button.contentEdgeInsets.bottom)
            make.trailing.equalToSuperview()
        }
        layout(isFirstSection: isFirstSection)
    }
    
    private func layout(isFirstSection: Bool) {
        if isFirstSection {
            backgroundView = topFillingBackgroundView
            topShadowView.isHidden = true
        } else {
            backgroundView = normalBackgroundView
            topShadowView.isHidden = false
        }
    }
    
}
