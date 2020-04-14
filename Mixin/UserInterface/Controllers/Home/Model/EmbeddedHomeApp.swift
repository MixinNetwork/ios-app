import UIKit
import MixinServices

final class EmbeddedHomeApp {
    
    static let wallet = EmbeddedHomeApp(id: 0, image: R.image.ic_home_app_wallet()!, name: R.string.localizable.wallet_title()) {
        UIApplication.homeViewController?.showWallet()
    }
    
    static let scan = EmbeddedHomeApp(id: 1, image: R.image.ic_home_app_scan()!, name: R.string.localizable.scan_qr_code()) {
        UIApplication.homeViewController?.showCamera()
    }
    
    static let camera = EmbeddedHomeApp(id: 2, image: R.image.ic_home_app_camera()!, name: R.string.localizable.action_camera()) {
        UIApplication.homeViewController?.showCamera()
    }
    
    static let all: [EmbeddedHomeApp] = [.wallet, .scan, .camera]
    
    let id: Int
    let image: UIImage
    let name: String
    let action: () -> Void
    
    init(id: Int, image: UIImage, name: String, action: @escaping () -> Void) {
        self.id = id
        self.image = image
        self.name = name
        self.action = action
    }
    
}
