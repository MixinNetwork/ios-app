import UIKit
import MixinServices

final class CheckmarkTokenCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var checkmarkView: CheckmarkView!
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tagLabel: InsetLabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(20, after: checkmarkView)
        tagLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        tagLabel.layer.cornerRadius = 4
        tagLabel.layer.masksToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        checkmarkView.status = selected ? .selected : .deselected
    }
    
    func load(address: AddressItem) {
        iconView.setIcon(address: address)
        titleLabel.text = address.label
        tagLabel.isHidden = true
        subtitleLabel.text = address.fullRepresentation
    }
    
    func load(token: MixinTokenItem) {
        iconView.setIcon(token: token)
        titleLabel.text = token.name
        if let name = token.chainTag {
            tagLabel.text = name
            tagLabel.isHidden = false
        } else {
            tagLabel.isHidden = true
        }
        subtitleLabel.text = token.localizedBalanceWithSymbol
    }
    
    func load(web3Token token: Web3TokenItem) {
        iconView.setIcon(web3Token: token)
        titleLabel.text = token.name
        if let name = token.chainTag {
            tagLabel.text = name
            tagLabel.isHidden = false
        } else {
            tagLabel.isHidden = true
        }
        subtitleLabel.text = token.localizedBalanceWithSymbol
    }
    
    func load(token: TradeOrder.Token) {
        iconView.setIcon(token: token, chain: token.chain)
        titleLabel.text = token.symbol
        if let name = token.chain?.name {
            tagLabel.text = name
            tagLabel.isHidden = false
        } else {
            tagLabel.isHidden = true
        }
        subtitleLabel.text = token.name
    }
    
    func load(coin: MarketAlertCoin) {
        iconView.setIcon(coin: coin)
        titleLabel.text = coin.symbol
        tagLabel.isHidden = true
        subtitleLabel.text = coin.name
    }
    
}
