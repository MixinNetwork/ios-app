import UIKit
import MixinServices

final class SwapAmountInputCell: UICollectionViewCell {
    
    @IBOutlet weak var sendView: UIView!
    @IBOutlet weak var sendStackView: UIStackView!
    @IBOutlet weak var sendNetworkLabel: UILabel!
    @IBOutlet weak var sendTokenStackView: UIStackView!
    @IBOutlet weak var sendAmountTextField: UITextField!
    @IBOutlet weak var sendLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var sendIconView: BadgeIconView!
    @IBOutlet weak var sendSymbolLabel: UILabel!
    @IBOutlet weak var sendFooterStackView: UIStackView!
    @IBOutlet weak var sendBalanceButton: UIButton!
    @IBOutlet weak var depositSendTokenButton: BusyButton!
    @IBOutlet weak var sendTokenNameLabel: UILabel!
    @IBOutlet weak var sendTokenButton: UIButton!
    
    @IBOutlet weak var swapButton: UIButton!

    @IBOutlet weak var receiveView: UIView!
    @IBOutlet weak var receiveStackView: UIStackView!
    @IBOutlet weak var receiveNetworkLabel: UILabel!
    @IBOutlet weak var receiveTokenStackView: UIStackView!
    @IBOutlet weak var receiveAmountTextField: UITextField!
    @IBOutlet weak var receiveLoadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var receiveIconView: BadgeIconView!
    @IBOutlet weak var receiveSymbolLabel: UILabel!
    @IBOutlet weak var receiveBalanceImageView: UIImageView!
    @IBOutlet weak var receiveBalanceLabel: UILabel!
    @IBOutlet weak var receiveTokenNameLabel: UILabel!
    @IBOutlet weak var receiveTokenButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        sendView.layer.masksToBounds = true
        sendView.layer.cornerRadius = 8
        sendStackView.setCustomSpacing(0, after: sendTokenStackView)
        sendLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        if var config = sendBalanceButton.configuration {
            config.contentInsets = .zero
            config.imagePadding = 6
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.preferredFont(forTextStyle: .caption1)
                outgoing.foregroundColor = R.color.text_quaternary()
                return outgoing
            }
            sendBalanceButton.configuration = config
        }
        receiveView.layer.masksToBounds = true
        receiveView.layer.cornerRadius = 8
        receiveStackView.setCustomSpacing(0, after: receiveTokenStackView)
        receiveLoadingIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        for symbolLabel in [sendSymbolLabel, receiveSymbolLabel] {
            symbolLabel!.setFont(
                scaledFor: .systemFont(ofSize: 16, weight: .medium),
                adjustForContentSize: true
            )
        }
        updateSendView(style: .loading)
        updateReceiveView(style: .loading)
    }
    
    func updateSendAmountTextField(amount: Decimal?) {
        sendAmountTextField.text = if let amount {
            NumberFormatter.userInputAmountSimulation.string(decimal: amount)
        } else {
            nil
        }
    }
    
    func updateReceiveAmountTextField(amount: Decimal?) {
        receiveAmountTextField.text = if let amount {
            NumberFormatter.userInputAmountSimulation.string(decimal: amount)
        } else {
            nil
        }
    }
    
}

extension SwapAmountInputCell {
    
    func updateSendView(style: SwapTokenSelectorStyle) {
        UIView.performWithoutAnimation {
            switch style {
            case .loading:
                sendTokenStackView.alpha = 0
                sendIconView.isHidden = false
                sendNetworkLabel.text = "Placeholder"
                sendNetworkLabel.alpha = 0 // Keeps the height
                depositSendTokenButton.isHidden = true
                sendBalanceButton.configuration?.title = "0"
                sendBalanceButton.alpha = 0
                sendBalanceButton.layoutIfNeeded()
                sendTokenNameLabel.text = nil
                sendLoadingIndicator.startAnimating()
            case .selectable:
                sendTokenStackView.alpha = 1
                sendIconView.isHidden = true
                sendIconView.prepareForReuse()
                sendSymbolLabel.text = R.string.localizable.select_token()
                sendNetworkLabel.text = "Placeholder"
                sendNetworkLabel.alpha = 0 // Keeps the height
                depositSendTokenButton.isHidden = true
                sendBalanceButton.configuration?.title = "0"
                sendBalanceButton.alpha = 0
                sendBalanceButton.layoutIfNeeded()
                sendTokenNameLabel.text = nil
                sendLoadingIndicator.stopAnimating()
            case .token(let token):
                sendTokenStackView.alpha = 1
                let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
                sendIconView.isHidden = false
                sendIconView.setIcon(swappableToken: token)
                sendSymbolLabel.text = token.symbol
                sendNetworkLabel.text = token.chain.name
                sendNetworkLabel.alpha = 1
                depositSendTokenButton.isHidden = token.decimalBalance != 0
                sendBalanceButton.configuration?.title = R.string.localizable.balance_abbreviation(balance)
                sendBalanceButton.alpha = 1
                sendBalanceButton.layoutIfNeeded()
                sendTokenNameLabel.text = token.name
                sendLoadingIndicator.stopAnimating()
            }
        }
    }
    
    func updateReceiveView(style: SwapTokenSelectorStyle) {
        switch style {
        case .loading:
            receiveTokenStackView.alpha = 0
            receiveIconView.isHidden = false
            receiveNetworkLabel.text = "0"
            receiveNetworkLabel.alpha = 0
            receiveBalanceImageView.alpha = 0
            receiveBalanceLabel.text = "0"
            receiveBalanceLabel.alpha = 0
            receiveTokenNameLabel.text = nil
            receiveLoadingIndicator.startAnimating()
        case .selectable:
            receiveTokenStackView.alpha = 1
            receiveIconView.isHidden = true
            receiveIconView.prepareForReuse()
            receiveSymbolLabel.text = R.string.localizable.select_token()
            receiveNetworkLabel.text = "0"
            receiveNetworkLabel.alpha = 0
            receiveBalanceImageView.alpha = 0
            receiveBalanceLabel.text = "0"
            receiveBalanceLabel.alpha = 0
            receiveTokenNameLabel.text = nil
            receiveLoadingIndicator.stopAnimating()
        case .token(let token):
            receiveTokenStackView.alpha = 1
            let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
            receiveIconView.isHidden = false
            receiveIconView.setIcon(swappableToken: token)
            receiveSymbolLabel.text = token.symbol
            receiveNetworkLabel.text = token.chain.name
            receiveNetworkLabel.alpha = 1
            receiveBalanceImageView.alpha = 1
            receiveBalanceLabel.text = R.string.localizable.balance_abbreviation(balance)
            receiveBalanceLabel.alpha = 1
            receiveTokenNameLabel.text = token.name
            receiveLoadingIndicator.stopAnimating()
        }
    }
    
}
