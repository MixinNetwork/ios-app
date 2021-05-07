import UIKit

protocol SearchHeaderViewDelegate: AnyObject {
    func searchHeaderViewDidSendMoreAction(_ view: SearchHeaderView)
}

class SearchHeaderView: UITableViewHeaderFooterView {
    
    static func height(isFirstSection: Bool) -> CGFloat {
        return isFirstSection ? 36 : 46
    }
    
    let label = UILabel()
    let button = UIButton(type: .system)
    let normalBackgroundView = UIView()
    let topShadowView = TopShadowView()
    
    var section: Int?
    
    weak var delegate: SearchHeaderViewDelegate?
    
    lazy var topFillingBackgroundView: InfiniteTopView = {
        let view = InfiniteTopView()
        view.backgroundColor = .background
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
    
    @objc func moreAction(_ sender: Any) {
        delegate?.searchHeaderViewDidSendMoreAction(self)
    }
    
    private func prepare() {
        normalBackgroundView.backgroundColor = .background
        backgroundView = normalBackgroundView
        clipsToBounds = false
        topShadowView.clipsToBounds = true
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.textColor = .text
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        button.setTitle(R.string.localizable.action_more(), for: .normal)
        button.setTitleColor(.highlightedText, for: .normal)
        button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        button.addTarget(self, action: #selector(moreAction(_:)), for: .touchUpInside)
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
