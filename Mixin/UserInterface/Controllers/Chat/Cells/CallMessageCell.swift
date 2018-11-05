import UIKit

class CallMessageCell: TextMessageCell {
    
    let prefixImageView = UIImageView(image: CallMessageViewModel.prefixImage)
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? CallMessageViewModel {
            prefixImageView.frame = viewModel.prefixFrame
        }
    }
    
    override func prepare() {
        super.prepare()
        prefixImageView.contentMode = .center
        contentView.addSubview(prefixImageView)
    }
    
}
