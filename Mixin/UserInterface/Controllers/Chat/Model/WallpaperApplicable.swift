import Foundation

protocol WallpaperApplicable {
    
    var conversationId: String { get }
    var backgroundImageView: UIImageView! { get }
    
    func updateBackgroundImage()
    
}

extension WallpaperApplicable {
    
    func updateBackgroundImage() {
        let image = Wallpaper.image(for: conversationId)
        let isBackgroundImageUndersized = backgroundImageView.frame.width > image.size.width
            || backgroundImageView.frame.height > image.size.height
        backgroundImageView.contentMode = isBackgroundImageUndersized ? .scaleAspectFill : .center
        backgroundImageView.image = image
    }
    
}
