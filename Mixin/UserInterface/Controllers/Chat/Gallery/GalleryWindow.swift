import UIKit

final class GalleryWindow: Window {
    
    let galleryViewController = GalleryViewController()
    
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        backgroundColor = .clear
        rootViewController = galleryViewController
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
