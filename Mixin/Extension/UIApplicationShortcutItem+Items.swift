import UIKit

extension UIApplicationShortcutItem {
    
    enum ItemType: String {
        case scanQrCode
        case wallet
        case myQrCode
    }
    
    static let scanQrCode = {
        let icon = if #available(iOS 26, *) {
            UIApplicationShortcutIcon(systemImageName: "qrcode.viewfinder")
        } else {
            UIApplicationShortcutIcon(templateImageName: R.image.ic_shortcut_scan_qr_code.name)
        }
        return UIApplicationShortcutItem(
            type: ItemType.scanQrCode.rawValue,
            localizedTitle: R.string.localizable.scan_qr_code(),
            localizedSubtitle: nil,
            icon: icon,
            userInfo: nil
        )
    }()
    
    static let wallet = {
        let icon = if #available(iOS 26, *) {
            UIApplicationShortcutIcon(systemImageName: "wallet.bifold")
        } else {
            UIApplicationShortcutIcon(templateImageName: R.image.ic_shortcut_wallet.name)
        }
        return UIApplicationShortcutItem(
            type: ItemType.wallet.rawValue,
            localizedTitle: R.string.localizable.wallets(),
            localizedSubtitle: nil,
            icon: icon,
            userInfo: nil
        )
    }()
    
    static let myQrCode = {
        let icon = if #available(iOS 26, *) {
            UIApplicationShortcutIcon(systemImageName: "qrcode")
        } else {
            UIApplicationShortcutIcon(templateImageName: R.image.ic_shortcut_my_qr_code.name)
        }
        return UIApplicationShortcutItem(
            type: ItemType.myQrCode.rawValue,
            localizedTitle: R.string.localizable.my_qr_code(),
            localizedSubtitle: nil,
            icon: icon,
            userInfo: nil
        )
    }()
    
}
