import UIKit

class TranscriptMessageCell: TextMessageCell {
    
    let transcriptBackgroundLayer = CALayer()
    let transcriptStackView = UIStackView()
    
    override func prepare() {
        super.prepare()
        transcriptBackgroundLayer.masksToBounds = true
        transcriptBackgroundLayer.cornerRadius = 7
        messageContentView.layer.insertSublayer(transcriptBackgroundLayer,
                                                below: contentLabel.layer)
        transcriptStackView.axis = .vertical
        transcriptStackView.alignment = .fill
        transcriptStackView.spacing = TranscriptMessageViewModel.transcriptInterlineSpacing
        messageContentView.addSubview(transcriptStackView)
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? TranscriptMessageViewModel {
            if viewModel.style.contains(.received) {
                transcriptBackgroundLayer.backgroundColor = UIColor.secondaryBackground.cgColor
            } else {
                transcriptBackgroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0.04).cgColor
            }
            transcriptBackgroundLayer.frame = viewModel.transcriptBackgroundFrame
            transcriptStackView.frame = viewModel.transcriptFrame
            let diff = viewModel.digests.count - transcriptStackView.arrangedSubviews.count
            if diff > 0 {
                for _ in 0..<diff {
                    let label = UILabel()
                    label.font = MessageFontSet.transcriptDigest.scaled
                    label.textColor = R.color.text_accessory()
                    label.numberOfLines = 1
                    transcriptStackView.addArrangedSubview(label)
                }
            } else if diff < 0 {
                for i in diff..<0 {
                    let index = transcriptStackView.arrangedSubviews.count + i
                    transcriptStackView.arrangedSubviews[index].isHidden = true
                }
            }
            for (index, digest) in viewModel.digests.enumerated() {
                let label = transcriptStackView.arrangedSubviews[index] as! UILabel
                label.text = digest
                label.isHidden = false
            }
        }
    }
    
}
