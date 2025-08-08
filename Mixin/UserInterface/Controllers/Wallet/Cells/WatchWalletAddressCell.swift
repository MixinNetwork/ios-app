import UIKit

final class WatchWalletAddressCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func watchWalletAddressCellDidSelectCopy(_ cell: WatchWalletAddressCell)
    }
    
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var chainImageView: UIImageView!
    
    weak var delegate: Delegate?
    
    @IBAction func copyAddress(_ sender: Any) {
        delegate?.watchWalletAddressCellDidSelectCopy(self)
    }
    
}
