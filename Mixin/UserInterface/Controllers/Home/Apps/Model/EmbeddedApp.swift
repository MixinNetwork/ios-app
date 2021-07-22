import UIKit
import MixinServices

final class EmbeddedApp {
    
    static let wallet = EmbeddedApp(id: App.walletAppId,
                                    icon: R.image.ic_home_app_wallet()!,
                                    categoryIcon: R.image.ic_app_category_wallet()!,
                                    name: R.string.localizable.wallet_title()) {
                                        WalletViewController.presentWallet()
    }
    
    static let scan = EmbeddedApp(id: App.scanAppId,
                                  icon: R.image.ic_home_app_scan()!,
                                  categoryIcon: R.image.ic_app_category_scan()!,
                                  name: R.string.localizable.scan_qr_code()) {
                                    UIApplication.homeViewController?.showCamera(asQrCodeScanner: true)
    }
    
    static let camera = EmbeddedApp(id: App.cameraAppId,
                                    icon: R.image.ic_home_app_camera()!,
                                    categoryIcon: R.image.ic_app_category_camera()!,
                                    name: R.string.localizable.action_camera()) {
                                        UIApplication.homeViewController?.showCamera(asQrCodeScanner: false)
    }
    
    static let all: [EmbeddedApp] = [.wallet, .scan, .camera]
    
    let id: String
    let icon: UIImage
    let categoryIcon: UIImage
    let name: String
    let action: () -> Void
    
    init(id: String, icon: UIImage, categoryIcon: UIImage, name: String, action: @escaping () -> Void) {
        self.id = id
        self.icon = icon
        self.categoryIcon = categoryIcon
        self.name = name
        self.action = action
    }
    
}
