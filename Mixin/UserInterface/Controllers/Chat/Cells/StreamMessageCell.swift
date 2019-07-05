import UIKit

class StreamMessageCell: PhotoRepresentableMessageCell {
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? StreamMessageViewModel {
            contentImageView.backgroundColor = .black
        }
    }
    
}
