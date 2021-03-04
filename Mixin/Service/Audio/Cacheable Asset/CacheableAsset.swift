import Foundation
import AVFoundation

final class CacheableAsset: AVURLAsset {
    
    private static let supportedSchemes = ["http", "https"]
    
    private let originalURL: URL
    private let loader: CacheableAssetLoader?
    
    override init(url URL: URL, options: [String : Any]? = nil) {
        self.originalURL = URL
        guard
            let id = URL.absoluteString.sha1,
            let cacheableURL = URLConverter.cacheableURL(from: URL),
            let loader = try? CacheableAssetLoader(id: id)
        else {
            self.loader = nil
            super.init(url: URL, options: options)
            return
        }
        self.loader = loader
        super.init(url: cacheableURL, options: options)
        resourceLoader.setDelegate(loader, queue: loader.queue)
    }
    
    deinit {
        loader?.invalidate()
    }
    
    static func isURLCacheable(_ url: URL) -> Bool {
        guard let scheme = url.scheme else {
            return false
        }
        return supportedSchemes.contains(scheme)
    }
    
}

extension CacheableAsset {
    
    enum URLConverter {
        
        private static let urlSchemePrefix = "mixin-ca-"
        
        static func cacheableURL(from originalURL: URL) -> URL? {
            guard var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: true) else {
                return nil
            }
            guard let scheme = components.scheme, supportedSchemes.contains(scheme) else {
                return nil
            }
            components.scheme = urlSchemePrefix + scheme
            return components.url
        }
        
        static func originalURL(from cacheableURL: URL) -> URL? {
            guard var components = URLComponents(url: cacheableURL, resolvingAgainstBaseURL: true) else {
                return nil
            }
            guard let scheme = components.scheme, scheme.hasPrefix(urlSchemePrefix) else {
                return nil
            }
            let start = scheme.index(scheme.startIndex, offsetBy: urlSchemePrefix.count)
            components.scheme = String(scheme[start...])
            return components.url
        }
        
    }
    
}
