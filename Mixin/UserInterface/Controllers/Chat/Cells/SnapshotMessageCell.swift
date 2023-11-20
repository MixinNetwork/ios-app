import UIKit
import MixinServices

class SnapshotMessageCell: DetailInfoMessageCell {
    
    let snapshotContentView = R.nib.snapshotMessageContentView(withOwner: nil)!
    
    var snapshotContentLeadingConstraint: NSLayoutConstraint!
    var snapshotContentTrailingConstraint: NSLayoutConstraint!
    
    override func prepare() {
        super.prepare()
        statusImageView.isHidden = true
        messageContentView.addSubview(snapshotContentView)
        snapshotContentView.snp.makeConstraints { make in
            make.top.equalTo(backgroundImageView.snp.top).offset(1)
        }
        snapshotContentLeadingConstraint = snapshotContentView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor)
        snapshotContentTrailingConstraint = snapshotContentView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor)
        NSLayoutConstraint.activate([snapshotContentLeadingConstraint, snapshotContentTrailingConstraint])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        snapshotContentView.tokenIconImageView.sd_cancelCurrentImageLoad()
        snapshotContentView.tokenIconImageView.image = nil
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? SnapshotMessageViewModel {
            snapshotContentLeadingConstraint.constant = viewModel.leadingConstant
            snapshotContentTrailingConstraint.constant = viewModel.trailingConstant
            if let string = viewModel.message.tokenIcon {
                snapshotContentView.tokenIconImageView.sd_setImage(with: URL(string: string), placeholderImage: nil, context: assetIconContext)
            }
            if let name = viewModel.message.tokenName, let symbol = viewModel.message.tokenSymbol {
                snapshotContentView.tokenNameLabel.text = name + " (" + symbol + ")"
            } else {
                snapshotContentView.tokenNameLabel.text = viewModel.message.tokenName ?? viewModel.message.tokenSymbol
            }
            snapshotContentView.amountLabel.text = viewModel.amount
            if let memo = viewModel.message.formattedSnapshotMemo, !memo.isEmpty {
                snapshotContentView.memoLabel.text = memo
                snapshotContentView.memoLabel.isHidden = false
            } else {
                snapshotContentView.memoLabel.isHidden = true
            }
        }
    }
    
}
