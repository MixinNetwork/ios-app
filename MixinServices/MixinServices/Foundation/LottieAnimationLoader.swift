import Foundation
import Alamofire
import Lottie

public class LottieAnimationLoader {
    
    public static let shared = LottieAnimationLoader()
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.LottieAnimationLoader", attributes: .concurrent)
    
    public func loadAnimation(with url: URL, completion: @escaping (LOTComposition?) -> Void) -> DownloadRequest? {
        let fileUrl = AppGroupContainer.documentsUrl
            .appendingPathComponent("Sticker")
            .appendingPathComponent("Lottie")
            .appendingPathComponent(url.absoluteString.md5())
        if let animation = LOTAnimationCache.shared().animation(forKey: fileUrl.path) {
            completion(animation)
            return nil
        } else {
            let request = AF.download(url, interceptor: nil) { (_, _) -> (URL, DownloadRequest.Options) in
                (fileUrl, .createIntermediateDirectories)
            }
            request.response(queue: queue, completionHandler: { [unowned request] (response) in
                guard !request.isCancelled else {
                    return
                }
                let composition = LOTComposition(filePath: fileUrl.path)
                DispatchQueue.main.async {
                    completion(composition)
                }
            })
            return request
        }
    }
    
}
