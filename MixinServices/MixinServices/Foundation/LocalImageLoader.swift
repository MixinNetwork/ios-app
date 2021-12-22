import Foundation
import SDWebImage

class LocalImageLoader: NSObject {
    
    enum Error: Swift.Error {
        case emptyUrl
        case cancelled
        case generateImage
    }
    
    private let queue = DispatchQueue(label: "one.mixin.services.local_image_loader")
    private let tokens = NSHashTable<LocalImageLoadToken>(options: .weakMemory)
    
}

extension LocalImageLoader: SDImageLoader {
    
    func canRequestImage(for url: URL?) -> Bool {
        return true
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
                let Image = (context?[.animatedImageClass] as? UIImage.Type) ?? SDAnimatedImage.self
                guard let image = Image.init(data: data) ?? UIImage(data: data) else {
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
