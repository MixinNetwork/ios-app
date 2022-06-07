import Foundation

protocol WallpaperApplicable {
    
    var conversationId: String { get }
    var backgroundImageView: UIImageView! { get }
    
    func updateBackgroundImage()
    
}

extension WallpaperApplicable {
    
    func updateBackgroundImage() {
        let wallpaper = Wallpaper.wallpaper(for: .conversation(conversationId))
        backgroundImageView.contentMode = wallpaper.contentMode(imageViewSize: backgroundImageView.frame.size)
        backgroundImageView.image = wallpaper.image
    }
    
}
