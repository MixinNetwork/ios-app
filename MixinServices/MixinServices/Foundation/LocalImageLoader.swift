import Foundation
import SDWebImage

class LocalImageLoader: NSObject {
    
    enum Error: Swift.Error {
        case emptyUrl
        case cancelled
        case generateImage
    }
    
    private let queue = DispatchQueue(label: "one.mixin.services.LocalImageLoader")
    private let tokens = NSHashTable<LocalImageLoadToken>(options: .weakMemory)
    
}

extension LocalImageLoader: SDImageLoader {
    
    func canRequestImage(for url: URL?) -> Bool {
        url != nil
    }
    
    func requestImage(with url: URL?, options: SDWebImageOptions = [], context: [SDWebImageContextOption : Any]?, progress progressBlock: SDImageLoaderProgressBlock?, completed completedBlock: SDImageLoaderCompletedBlock? = nil) -> SDWebImageOperation? {
        guard let url = url else {
            completedBlock?(nil, nil, Error.emptyUrl, true)
            return nil
        }
        progressBlock?(0, 2, url)
        let token = LocalImageLoadToken()
        tokens.add(token)
        queue.async {
            guard !token.isCancelled else {
                completedBlock?(nil, nil, Error.cancelled, true)
                return
            }
            do {
                let data = try Data(contentsOf: url)
                progressBlock?(1, 2, url)
                
                guard !token.isCancelled else {
                    completedBlock?(nil, nil, Error.cancelled, true)
                    return
                }
                let decodeFirstFrame = options.contains(.decodeFirstFrameOnly)
                let Image = (context?[.animatedImageClass] as? UIImage.Type) ?? SDAnimatedImage.self
                
                let decodeOptions: [SDImageCoderOption: Any]?
                if let size = context?[.imageThumbnailPixelSize] as? CGSize {
                    decodeOptions = [.decodeThumbnailPixelSize: size]
                } else {
                    decodeOptions = nil
                }
                
                var image: UIImage?
                if !decodeFirstFrame, let Image = Image as? SDAnimatedImage.Type {
                    image = Image.init(data: data, scale: 1, options: decodeOptions)
                }
                if image == nil {
                    image = SDImageIOCoder.shared.decodedImage(with: data, options: decodeOptions)
                }
                
                guard let image = image else {
                    completedBlock?(nil, nil, Error.generateImage, true)
                    return
                }
                
                guard !token.isCancelled else {
                    completedBlock?(nil, nil, Error.cancelled, true)
                    return
                }
                progressBlock?(2, 2, url)
                completedBlock?(image, data, nil, true)
            } catch {
                completedBlock?(nil, nil, error, true)
            }
        }
        return token
    }
    
    func shouldBlockFailedURL(with url: URL, error: Swift.Error) -> Bool {
        return false
    }
    
}
