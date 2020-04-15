import UIKit
import MixinServices

final class EmbeddedHomeApp {
    
    static let wallet = EmbeddedHomeApp(id: 0,
                                        icon: R.image.ic_home_app_wallet()!,
                                        categoryIcon: R.image.ic_app_category_wallet()!,
                                        name: R.string.localizable.wallet_title()) {
        UIApplication.homeViewController?.showWallet()
    }
    
    static let scan = EmbeddedHomeApp(id: 1,
                                      icon: R.image.ic_home_app_scan()!,
                                      categoryIcon: R.image.ic_app_category_scan()!,
                                      name: R.string.localizable.scan_qr_code()) {
        UIApplication.homeViewController?.showCamera(asQrCodeScanner: true)
    }
    
    static let camera = EmbeddedHomeApp(id: 2,
                                        icon: R.image.ic_home_app_camera()!,
                                        categoryIcon: R.image.ic_app_category_camera()!,
                                        name: R.string.localizable.action_camera()) {
        UIApplication.homeViewController?.showCamera(asQrCodeScanner: false)
    }
    
    static let all: [EmbeddedHomeApp] = [.wallet, .scan, .camera]
    
    let id: Int
    let icon: UIImage
    let categoryIcon: UIImage
    let name: String
    let action: () -> Void
    
    init(id: Int, icon: UIImage, categoryIcon: UIImage, name: String, action: @escaping () -> Void) {
        self.id = id
        self.icon = icon
        self.categoryIcon = categoryIcon
        self.name = name
        self.action = action
    }
    
}
