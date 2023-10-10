import UIKit

final class CompactComboBoxView: UIControl {
    
    let iconImageView = UIImageView()
    
    var text: String? {
        didSet {
            label.text = text
        }
    }
    
    private let button = UIButton(type: .system)
    private let label = UILabel()
    private let imageView = UIImageView()
    
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
        label.text = text
        label.textColor = R.color.text()
        label.font = .systemFont(ofSize: 14)
        label.adjustsFontSizeToFitWidth = true
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.image = R.image.ic_selector_down()
        imageView.tintColor = R.color.text_accessory()
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        let stackView = UIStackView(arrangedSubviews: [iconImageView, label, imageView])
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
        
        addSubview(button)
        button.snp.makeEdgesEqualToSuperview()
        button.addTarget(self, action: #selector(sendTouchUpInside(_:)), for: .touchUpInside)
    }
    
}
