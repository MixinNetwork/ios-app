import UIKit

extension UIImage: InstanceInitializable {
    
    public convenience init?(thumbnailString: String?) {
        guard let string = thumbnailString else {
            return nil
        }
        if let image = UIImage(blurHash: string, size: .blurHashThumbnail) {
            self.init(instance: image as! Self)
        } else if let data = Data(base64Encoded: string), let image = UIImage(data: data) {
            self.init(instance: image as! Self)
        } else {
            return nil
        }
    }
    
}
