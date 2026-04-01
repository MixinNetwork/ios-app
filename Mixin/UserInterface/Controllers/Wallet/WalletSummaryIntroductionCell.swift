import UIKit

final class WalletSummaryIntroductionCell: UICollectionViewCell {
    
    enum Content {
        case imported
        case watch
        case upgradePlan
        case createSafe
    }
    
    protocol Delegate: AnyObject {
        func walletSummaryIntroductionCell(_ cell: WalletSummaryIntroductionCell, didSelectActionAtIndex index: Int)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var actionView: PillActionView!
    @IBOutlet weak var actionIndicatorImageView: UIImageView!
    
    var content: Content? {
        didSet {
            load(content: content)
        }
    }
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 13
        contentView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        actionView.layer.cornerRadius = 12
        actionView.layer.masksToBounds = true
        actionView.delegate = self
    }
    
    private func load(content: Content?) {
        switch content {
        case .none:
            break
        case .imported:
            titleLabel.text = R.string.localizable.import_wallet_title()
            descriptionLabel.text = R.string.localizable.import_wallet_empty_description()
            imageView.image = R.image.wallet_intro_imported()
            actionView.backgroundColor = R.color.background_quaternary()
            actionView.actions = [
                .init(title: R.string.localizable.import(), style: .vibrant),
                .init(title: R.string.localizable.learn_more()),
            ]
            actionIndicatorImageView.tintColor = UIColor(displayP3RgbValue: 0x999999)
        case .watch:
            titleLabel.text = R.string.localizable.add_watch_address()
            descriptionLabel.text = R.string.localizable.watch_wallet_empty_description()
            imageView.image = R.image.wallet_intro_watch()
            actionView.backgroundColor = R.color.background_quaternary()
            actionView.actions = [
                .init(title: R.string.localizable.add(), style: .vibrant),
                .init(title: R.string.localizable.learn_more()),
            ]
            actionIndicatorImageView.tintColor = UIColor(displayP3RgbValue: 0x999999)
        case .upgradePlan:
            titleLabel.text = R.string.localizable.upgrade_plan()
            descriptionLabel.text = R.string.localizable.upgrade_safe_description()
            imageView.image = R.image.wallet_intro_safe()
            actionView.backgroundColor = R.color.background_quaternary()
            actionView.actions = [
                .init(title: R.string.localizable.upgrade(), style: .vibrant),
                .init(title: R.string.localizable.learn_more()),
            ]
            actionIndicatorImageView.tintColor = UIColor(displayP3RgbValue: 0x999999)
        case .createSafe:
            titleLabel.text = R.string.localizable.create_safe()
            descriptionLabel.text = R.string.localizable.create_safe_description()
            imageView.image = R.image.safe_wallet_introduction()
            actionView.backgroundColor = R.color.theme()
            actionView.actions = [
                .init(title: R.string.localizable.guideline(), style: .filled),
            ]
            actionIndicatorImageView.tintColor = .white
        }
    }
    
}

extension WalletSummaryIntroductionCell: PillActionView.Delegate {
    
    func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int) {
        delegate?.walletSummaryIntroductionCell(self, didSelectActionAtIndex: index)
    }
    
}
