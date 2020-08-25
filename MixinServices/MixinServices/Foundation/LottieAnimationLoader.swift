import Foundation
import Alamofire
import Lottie

public class LottieAnimationLoader {
    
    public class Token {
    
        @Synchronized(value: false)
        public private(set) var isCancelled: Bool
        
        @Synchronized(value: nil)
        fileprivate var request: DownloadRequest?
        
        public func cancel() {
            isCancelled = true
            request?.cancel()
        }
        
    }
    
    public static let shared = LottieAnimationLoader()
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.LottieAnimationLoader", attributes: .concurrent)
    
    public func loadAnimation(with url: URL, completion: @escaping (LOTComposition?) -> Void) -> Token {
        let token = Token()
        
        queue.async {
            let fileUrl = AppGroupContainer.documentsUrl
                .appendingPathComponent("Sticker")
                .appendingPathComponent("Lottie")
                .appendingPathComponent(url.absoluteString.md5())
            let memoryCached = LOTAnimationCache.shared().animation(forKey: fileUrl.path)
            let diskCached = LOTComposition(filePath: fileUrl.path)
            
            if let animation = memoryCached ?? diskCached {
                DispatchQueue.main.async {
                    guard !token.isCancelled else {
                        return
                    }
                    completion(animation)
                }
            } else {
                let request = AF.download(url, interceptor: nil) { (_, _) -> (URL, DownloadRequest.Options) in
                    (fileUrl, .createIntermediateDirectories)
                }.response(queue: self.queue, completionHandler: { (response) in
                    guard !token.isCancelled else {
                        return
                    }
                    let composition = LOTComposition(filePath: fileUrl.path)
                    DispatchQueue.main.async {
                        guard !token.isCancelled else {
                            return
                        }
                        completion(composition)
                    }
                })
                token.request = request
            }
        }
        
        return token
    }
    
}
