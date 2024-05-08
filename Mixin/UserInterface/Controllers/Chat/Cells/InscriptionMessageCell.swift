import UIKit

final class InscriptionMessageCell: DetailInfoMessageCell {
    
    let inscriptionContentView = R.nib.inscriptionContentView(withOwner: nil)!
    
    var snapshotContentLeadingConstraint: NSLayoutConstraint!
    var snapshotContentTrailingConstraint: NSLayoutConstraint!
    
    override func prepare() {
        super.prepare()
        statusImageView.isHidden = true
        messageContentView.addSubview(inscriptionContentView)
        inscriptionContentView.snp.makeConstraints { make in
            make.top.equalTo(backgroundImageView.snp.top).offset(1)
        }
        snapshotContentLeadingConstraint = inscriptionContentView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor)
        snapshotContentTrailingConstraint = inscriptionContentView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor)
        NSLayoutConstraint.activate([snapshotContentLeadingConstraint, snapshotContentTrailingConstraint])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        inscriptionContentView.prepareForReuse()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? InscriptionMessageViewModel {
            snapshotContentLeadingConstraint.constant = viewModel.leadingConstant
            snapshotContentTrailingConstraint.constant = viewModel.trailingConstant
            let message = viewModel.message
            if let contentType = message.inscriptionContentType,
               contentType.starts(with: "image/"),
               let string = message.inscriptionContentURL,
               let url = URL(string: string)
            {
                inscriptionContentView.imageView.sd_setImage(with: url)
            } else {
                inscriptionContentView.imageView.image = R.image.inscription_Intaglio()
            }
            inscriptionContentView.nameLabel.text = message.inscriptionCollectionName
            inscriptionContentView.sequenceLabel.text = "#\(message.inscriptionSequence ?? 0)"
            inscriptionContentView.hashView.content = message.inscriptionHash
        }
    }
    
}
