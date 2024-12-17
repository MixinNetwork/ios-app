import UIKit

final class CustomerServiceViewController: PopupTitledWebViewController {
    
    init() {
        super.init(
            title: R.string.localizable.mixin_support(),
            subtitle: R.string.localizable.ask_me_anything(),
            url: .customerService
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
}
