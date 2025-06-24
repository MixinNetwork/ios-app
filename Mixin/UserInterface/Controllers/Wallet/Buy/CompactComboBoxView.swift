import UIKit
import MixinServices

final class CompactComboBoxView: UIControl {
    
    enum AccessoryView {
        case activityIndicator
        case disclosure
    }
    
    let iconImageView = PlainTokenIconView(frame: .zero)
    
    var text: String? {
        didSet {
            label.text = text
        }
    }
    
    var accessoryView: AccessoryView = .activityIndicator {
        didSet {
            switch accessoryView {
            case .activityIndicator:
                activityIndicator.startAnimating()
                disclosureImageView.isHidden = true
            case .disclosure:
                activityIndicator.stopAnimating()
                disclosureImageView.isHidden = false
            }
        }
    }
    
    private let button = UIButton(type: .system)
    private let label = UILabel()
    private let activityIndicator = ActivityIndicatorView()
    private let disclosureImageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    @objc private func sendTouchUpInside(_ sender: Any) {
        sendActions(for: .touchUpInside)
    }
    
    private func loadSubviews() {
        iconImageView.setContentHuggingPriority(.required, for: .horizontal)
        iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.textColor = R.color.text()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.text = text
        activityIndicator.style = .custom(diameter: 10, lineWidth: 2)
        activityIndicator.tintColor = R.color.button_background_disabled()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        activityIndicator.setContentCompressionResistancePriority(.required, for: .horizontal)
        activityIndicator.startAnimating()
        disclosureImageView.image = R.image.ic_selector_down()
        disclosureImageView.tintColor = R.color.text_tertiary()
        disclosureImageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        disclosureImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        disclosureImageView.isHidden = true
        
        let stackView = UIStackView(arrangedSubviews: [
            iconImageView, label, activityIndicator, disclosureImageView
        ])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 10
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-12)
            make.top.bottom.equalToSuperview()
        }
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(26)
        }
        activityIndicator.snp.makeConstraints { make in
            make.width.equalTo(16).priority(.almostRequired)
        }
        
        addSubview(button)
        button.snp.makeEdgesEqualToSuperview()
        button.addTarget(self, action: #selector(sendTouchUpInside(_:)), for: .touchUpInside)
    }
    
    func load(currency: Currency) {
        iconImageView.prepareForReuse()
        iconImageView.image = currency.icon
        text = currency.code
    }
    
    func load(token: any Token) {
        iconImageView.prepareForReuse()
        iconImageView.setIcon(token: token)
        text = token.symbol
    }
    
}
