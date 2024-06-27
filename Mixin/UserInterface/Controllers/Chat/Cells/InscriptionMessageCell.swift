import UIKit

final class InscriptionMessageCell: DetailInfoMessageCell {
    
    let inscriptionContentView = R.nib.inscriptionContentView(withOwner: nil)!
    
    var contentLeadingConstraint: NSLayoutConstraint!
    var contentTrailingConstraint: NSLayoutConstraint!
    
    override func prepare() {
        super.prepare()
        statusImageView.isHidden = true
        messageContentView.addSubview(inscriptionContentView)
        inscriptionContentView.snp.makeConstraints { make in
            make.top.equalTo(backgroundImageView.snp.top).offset(1)
        }
        contentLeadingConstraint = inscriptionContentView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor)
        contentTrailingConstraint = inscriptionContentView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor)
        NSLayoutConstraint.activate([contentLeadingConstraint, contentTrailingConstraint])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        inscriptionContentView.prepareForReuse()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? InscriptionMessageViewModel {
            contentLeadingConstraint.constant = viewModel.leadingConstant
            contentTrailingConstraint.constant = viewModel.trailingConstant
            inscriptionContentView.reloadData(with: viewModel.message.inscription)
        }
    }
    
}
