import UIKit

final class PopupTitleView: UIView {
    
    let contentStackView = UIStackView()
    let titleStackView = UIStackView()
    let titleLabel = UILabel()
    let closeButton = UIButton()
    
    lazy var imageView: AvatarImageView = {
        let view = AvatarImageView()
        contentStackView.insertArrangedSubview(view, at: 0)
        view.snp.makeConstraints { make in
            make.width.equalTo(view.snp.height)
            make.width.equalTo(30)
        }
        return view
    }()
    
    lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.text_accessory()
        label.font = .scaledFont(ofSize: 12, weight: .regular)
        label.adjustsFontForContentSizeCategory = true
        titleStackView.addArrangedSubview(label)
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubviews()
    }
    
    private func addSubviews() {
        backgroundColor = .background
        
        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.distribution = .fill
        contentStackView.spacing = 10
        addSubview(contentStackView)
        
        titleStackView.axis = .vertical
        titleStackView.alignment = .fill
        titleStackView.distribution = .fill
        titleStackView.spacing = 2
        contentStackView.addArrangedSubview(titleStackView)
        
        titleLabel.textColor = .text
        titleLabel.font = .scaledFont(ofSize: 18, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleStackView.addArrangedSubview(titleLabel)
        
        closeButton.setImage(R.image.ic_dialog_close(), for: .normal)
        closeButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        addSubview(closeButton)
        
        contentStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(closeButton.snp.leading).offset(-8).priority(.almostRequired)
        }
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(44)
            make.top.equalToSuperview().offset(13)
            make.trailing.equalToSuperview().offset(-13)
        }
    }
    
}
