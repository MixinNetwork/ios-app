import UIKit

public enum ImageUploadSanitizer {
    
    public static let maxSize = CGSize(width: 1920, height: 1920)
    
    public static func sanitizedImage(from rawImage: UIImage) -> (image: UIImage?, data: Data?) {
        guard let rawData = rawImage.jpegData(compressionQuality: JPEGCompressionQuality.high) else {
            return (nil, nil)
        }
        let isRawImageUndersized = min(rawImage.size.width, rawImage.size.height) <= min(maxSize.width, maxSize.height)
            && max(rawImage.size.width, rawImage.size.height) <= max(maxSize.width, maxSize.height)
        if imageWithRatioMaybeAnArticle(rawImage.size) || isRawImageUndersized {
            return (rawImage, rawData)
        } else {
            let newSize = rawImage.size.sizeThatFits(maxSize)
            let newImage = rawImage.imageByScaling(to: newSize)
            let newData = newImage?.jpegData(compressionQuality: JPEGCompressionQuality.high)
            return (newImage, newData)
        }
    }
    
}
