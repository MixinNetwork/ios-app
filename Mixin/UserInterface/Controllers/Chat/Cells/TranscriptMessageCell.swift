import UIKit

class TranscriptMessageCell: TextMessageCell {
    
    let transcriptBackgroundView = UIView()
    let transcriptStackView = UIStackView()
    let trailingInfoPlaceholder = UIView()
    
    private var digestStackViews: [UIStackView] = []
    private var digestLabels: [UILabel] = []
    
    override func prepare() {
        super.prepare()
        transcriptBackgroundView.clipsToBounds = true
        transcriptBackgroundView.layer.cornerRadius = 7
        messageContentView.insertSubview(transcriptBackgroundView, aboveSubview: backgroundImageView)
        
        transcriptStackView.axis = .vertical
        transcriptStackView.alignment = .fill
        transcriptStackView.distribution = .equalSpacing
        transcriptStackView.spacing = TranscriptMessageViewModel.transcriptInterlineSpacing
        messageContentView.addSubview(transcriptStackView)
        
        trailingInfoPlaceholder.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? TranscriptMessageViewModel {
            if viewModel.style.contains(.received) {
                transcriptBackgroundView.backgroundColor = .secondaryBackground
            } else {
                transcriptBackgroundView.backgroundColor = .black.withAlphaComponent(0.04)
            }
            transcriptBackgroundView.frame = viewModel.transcriptBackgroundFrame
            transcriptStackView.frame = viewModel.transcriptFrame
            let diff = viewModel.digests.count - digestStackViews.count
            if diff > 0 {
                for _ in 0..<diff {
                    let label = UILabel()
                    label.font = MessageFontSet.transcriptDigest.scaled
                    label.textColor = R.color.text_accessory()
                    label.numberOfLines = 1
                    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    digestLabels.append(label)
                    let stackView = UIStackView()
                    stackView.axis = .horizontal
                    stackView.distribution = .fill
                    stackView.alignment = .fill
                    stackView.addArrangedSubview(label)
                    stackView.spacing = 8
                    digestStackViews.append(stackView)
                    transcriptStackView.addArrangedSubview(stackView)
                }
            } else if diff < 0 {
                for i in diff..<0 {
                    let index = digestStackViews.count + i
                    digestStackViews[index].isHidden = true
                }
            }
            for (index, digest) in viewModel.digests.enumerated() {
                let stackView = digestStackViews[index]
                let label = digestLabels[index]
                stackView.isHidden = false
                label.text = digest
                if index == viewModel.digests.count - 1, trailingInfoPlaceholder.superview != stackView {
                    trailingInfoPlaceholder.removeFromSuperview()
                    stackView.addArrangedSubview(trailingInfoPlaceholder)
                    let placeholderWidth = statusImageView.frame.maxX - encryptedImageView.frame.minX
                    trailingInfoPlaceholder.widthAnchor.constraint(equalToConstant: placeholderWidth).isActive = true
                }
            }
        }
    }
    
}
