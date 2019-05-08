import UIKit

class IconPrefixedTextMessageCell: TextMessageCell {
    
    let prefixImageView = UIImageView(frame: CGRect(origin: .zero, size: CallMessageViewModel.prefixSize))
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? IconPrefixedTextMessageViewModel {
            prefixImageView.frame = viewModel.prefixFrame
            prefixImageView.image = viewModel.prefixImage
        }
    }
    
    override func prepare() {
        super.prepare()
        prefixImageView.contentMode = .center
        contentView.addSubview(prefixImageView)
    }
    
}
