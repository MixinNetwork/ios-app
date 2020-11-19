import UIKit

public enum ImageUploadSanitizer {
    
    public static let maxSize = CGSize(width: 1920, height: 1920)
    
    public static func sanitizedImage(from rawImage: UIImage) -> (image: UIImage?, data: Data?) {
        let isRawImageUndersized = min(rawImage.size.width, rawImage.size.height) <= min(maxSize.width, maxSize.height)
            && max(rawImage.size.width, rawImage.size.height) <= max(maxSize.width, maxSize.height)
        if imageWithRatioMaybeAnArticle(rawImage.size) {
            let data = rawImage.jpegData(compressionQuality: JPEGCompressionQuality.max)
            return (rawImage, data)
        } else if isRawImageUndersized {
            let data = rawImage.jpegData(compressionQuality: JPEGCompressionQuality.high)
            return (rawImage, data)
        } else {
            let newSize = rawImage.size.sizeThatFits(maxSize)
            let newImage = rawImage.imageByScaling(to: newSize)
            let data = newImage?.jpegData(compressionQuality: JPEGCompressionQuality.high)
            return (newImage, data)
        }
    }
    
}
