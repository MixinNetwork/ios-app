import UIKit
import MixinServices

final class AddressReceiversCell: UITableViewCell {

    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var receiversStackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(12, after: titleStackView)
    }
    
    func reloadData(token: TokenItem, recipients: [SafeMultisigResponse.Safe.Recipient]) {
        for view in receiversStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        captionLabel.text = if recipients.count > 1 {
            R.string.localizable.receivers()
        } else {
            R.string.localizable.receiver()
        }
        for recipient in recipients {
            let amount = CurrencyFormatter.localizedString(
                from: recipient.amount,
                format: .precision,
                sign: .never,
                symbol: .custom(token.symbol)
            )
            let row = RowView(label: recipient.label, address: recipient.address, amount: amount)
            receiversStackView.addArrangedSubview(row)
        }
    }
    
    private class RowView: UIView {
        
        private let addressLabel = UILabel()
        private let amountLabel = UILabel()
        private let addressLabelSpacing: CGFloat = 9
        
        private var labelLabel: UILabel?
        
        init(label: String?, address: String, amount: String) {
            super.init(frame: .zero)
            
            addressLabel.numberOfLines = 0
            addressLabel.lineBreakMode = .byCharWrapping
            addSubview(addressLabel)
            addressLabel.snp.makeConstraints { make in
                make.leading.bottom.equalToSuperview()
                make.width.equalToSuperview().multipliedBy(200.0 / 320.0)
            }
            
            amountLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            amountLabel.textColor = R.color.text_secondary()
            amountLabel.numberOfLines = 0
            amountLabel.text = amount
            amountLabel.textAlignment = .right
            addSubview(amountLabel)
            amountLabel.snp.makeConstraints { make in
                make.trailing.top.bottom.equalToSuperview()
                make.leading.equalTo(addressLabel.snp.trailing).offset(8)
            }
            
            if let label {
                let labelLabel = InsetLabel()
                labelLabel.contentInset = UIEdgeInsets(top: 2, left: 10, bottom: 2, right: 10)
                labelLabel.font = .systemFont(ofSize: 12)
                labelLabel.backgroundColor = R.color.address_label_background()
                labelLabel.textColor = R.color.text_secondary()
                labelLabel.text = label
                addSubview(labelLabel)
                labelLabel.snp.makeConstraints { make in
                    make.top.equalToSuperview().offset(-2)
                    make.leading.equalToSuperview()
                    make.trailing.lessThanOrEqualTo(addressLabel.snp.trailing)
                }
                labelLabel.layer.borderWidth = 1
                labelLabel.layer.masksToBounds = true
                self.labelLabel = labelLabel
                
                var addressAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                    .foregroundColor: R.color.text_secondary()!,
                ]
                if labelLabel.intrinsicContentSize.width < 100 {
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.firstLineHeadIndent = labelLabel.intrinsicContentSize.width + addressLabelSpacing
                    paragraphStyle.lineSpacing = 1
                    addressAttributes[.paragraphStyle] = paragraphStyle
                    addressLabel.snp.makeConstraints { make in
                        make.top.equalToSuperview()
                    }
                } else {
                    addressLabel.snp.makeConstraints { make in
                        make.top.equalTo(labelLabel.snp.bottom)
                    }
                }
                addressLabel.attributedText = NSAttributedString(string: address, attributes: addressAttributes)
                updateLabelBorderColor()
            } else {
                addressLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
                addressLabel.textColor = R.color.text_secondary()
                addressLabel.text = address
                addressLabel.snp.makeConstraints { make in
                    make.top.equalToSuperview()
                }
            }
        }
        
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            if let label = labelLabel {
                label.layer.cornerRadius = label.bounds.height / 2
            }
        }
        
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateLabelBorderColor()
            }
        }
        
        private func updateLabelBorderColor() {
            labelLabel?.layer.borderColor = R.color
                .address_label_outline()!
                .resolvedColor(with: traitCollection)
                .cgColor
        }
        
    }
    
}
