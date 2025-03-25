import UIKit

final class MarketAlertItemView: UIView {
    
    @IBOutlet weak var iconImageView: MarketColorTintedImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        actionButton.showsMenuAsPrimaryAction = true
    }
    
    func load(viewModel: MarketAlertViewModel.AlertViewModel) {
        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title
        switch viewModel.alert.status {
        case .running:
            switch viewModel.alert.type.displayType {
            case .constant:
                iconImageView.tintColor = R.color.theme()
            case .increasing:
                iconImageView.marketColor = .rising
            case .decreasing:
                iconImageView.marketColor = .falling
            }
            titleLabel.textColor = R.color.text()
        case .paused:
            iconImageView.tintColor = R.color.icon_tint_tertiary()
            titleLabel.textColor = R.color.text_tertiary()
        }
        subtitleLabel.text = viewModel.subtitle
    }
    
}
