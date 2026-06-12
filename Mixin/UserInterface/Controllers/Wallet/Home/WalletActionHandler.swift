import UIKit
import MixinServices

protocol WalletActionHandler: WalletOverviewCell.Delegate {
    func buy()
    func receive()
}
