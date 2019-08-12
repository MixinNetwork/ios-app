import UIKit

enum NormalNetworkOperationIconSet: NetworkOperationIconSet {
    
    static var play: UIImage {
        return R.image.ic_play()!
    }
    
    static var upload: UIImage {
        return R.image.ic_file_upload()!
    }
    
    static var download: UIImage {
        return R.image.ic_file_download()!
    }
    
    static var expired: UIImage {
        return R.image.ic_file_expired()!
    }
    
    static var cancel: UIImage {
        return R.image.ic_file_cancel()!
    }
    
}
