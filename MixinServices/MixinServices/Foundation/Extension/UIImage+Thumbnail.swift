import UIKit

extension UIImage: InstanceInitializable {
    
    private static let blurHashImageSize = CGSize(width: 32, height: 32)
    
    public convenience init?(thumbnailString: String?) {
        guard let string = thumbnailString else {
            return nil
        }
        if let image = UIImage(blurHash: string, size: Self.blurHashImageSize) {
            self.init(instance: image as! Self)
        } else if let data = Data(base64Encoded: string), let image = UIImage(data: data) {
            self.init(instance: image as! Self)
        } else {
            return nil
        }
    }
    
}
