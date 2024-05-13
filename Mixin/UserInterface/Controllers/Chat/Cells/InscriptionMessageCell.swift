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
            inscriptionContentView.imageView.image = R.image.inscription_intaglio()
            inscriptionContentView.imageView.contentMode = .center
            if let inscription = viewModel.message.inscription {
                if let url = inscription.inscriptionImageContentURL {
                    inscriptionContentView.imageView.image = nil
                    inscriptionContentView.imageView.sd_setImage(with: url)
                    inscriptionContentView.imageView.contentMode = .scaleAspectFill
                }
                inscriptionContentView.nameLabel.text = inscription.collectionName
                inscriptionContentView.sequenceLabel.text = inscription.sequenceRepresentation
                inscriptionContentView.hashView.content = inscription.inscriptionHash
            } else {
                inscriptionContentView.nameLabel.text = ""
                inscriptionContentView.sequenceLabel.text = ""
                inscriptionContentView.hashView.content = nil
            }
        }
    }
    
}
