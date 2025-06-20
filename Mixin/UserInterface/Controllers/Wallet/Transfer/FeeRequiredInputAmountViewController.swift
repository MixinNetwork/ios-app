import UIKit
import MixinServices

class FeeRequiredInputAmountViewController: InputAmountViewController {
    
    var feeAttributes: AttributeContainer {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        container.foregroundColor = R.color.text_tertiary()
        return container
    }
    
    private(set) weak var feeStackView: UIStackView?
    private(set) weak var addFeeButton: UIButton?
    private(set) weak var feeActivityIndicator: ActivityIndicatorView?
    private(set) weak var changeFeeButton: UIButton?
    
    @objc func addFee(_ sender: Any) {
        
    }
    
    func addFeeView() {
        let titleLabel = InsetLabel()
        titleLabel.contentInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        titleLabel.text = R.string.localizable.network_fee()
        titleLabel.textColor = R.color.text_tertiary()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let activityIndicator = ActivityIndicatorView()
        activityIndicator.style = .custom(diameter: 16, lineWidth: 2)
        activityIndicator.tintColor = R.color.icon_tint_tertiary()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.isAnimating = true
        self.feeActivityIndicator = activityIndicator
        
        var config: UIButton.Configuration = .plain()
        config.baseBackgroundColor = .clear
        config.imagePlacement = .trailing
        config.imagePadding = 14
        config.attributedTitle = AttributedString("0", attributes: feeAttributes)
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 5, bottom: 7, trailing: 12)
        let button = UIButton(configuration: config)
        button.tintColor = R.color.icon_tint_tertiary()
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.alpha = 0
        self.changeFeeButton = button
        
        let feeStackView = UIStackView(arrangedSubviews: [titleLabel, activityIndicator, button])
        feeStackView.axis = .horizontal
        feeStackView.alignment = .center
        
        accessoryStackView.insertArrangedSubview(feeStackView, at: 0)
        feeStackView.snp.makeConstraints { make in
            make.width.equalTo(view.snp.width).offset(-56)
        }
        self.feeStackView = feeStackView
    }
    
    func addAddFeeButton(symbol: String) {
        if addFeeButton == nil {
            var config: UIButton.Configuration = .plain()
            config.baseBackgroundColor = .clear
            config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 5, bottom: 7, trailing: 5)
            let button = UIButton(configuration: config)
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.addTarget(self, action: #selector(addFee(_:)), for: .touchUpInside)
            feeStackView?.insertArrangedSubview(button, at: 1)
            addFeeButton = button
        }
        addFeeButton?.configuration?.attributedTitle = AttributedString(
            R.string.localizable.add_token(symbol),
            attributes: addTokenAttributes
        )
    }
    
    func removeAddFeeButton() {
        addFeeButton?.removeFromSuperview()
    }
    
}
