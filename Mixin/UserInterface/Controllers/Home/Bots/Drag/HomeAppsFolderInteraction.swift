import Foundation

protocol HomeAppsFolderInteraction {
    var dragInteraction: HomeAppsDragInteraction { get set }
    var item: BotItem { get set }
    var isDismissing: Bool { get set }
    var placeholderView: UIView { get set }
}

class HomeAppsFolderCreation: HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction
    var destinationApp: Bot
    var placeholderView: UIView
    var isDismissing: Bool = false
    
    var item: BotItem
    
    required init(dragInteraction: HomeAppsDragInteraction, destinationApp: Bot, placeholderView: UIView) {
        self.dragInteraction = dragInteraction
        self.destinationApp = destinationApp
        self.item = destinationApp
        self.placeholderView = placeholderView
    }
    
}

class HomeAppsFolderDrop: HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction
    var folder: BotFolder
    var placeholderView: UIView
    var isDismissing: Bool = false
    
    var item: BotItem
    
    required init(dragInteraction: HomeAppsDragInteraction, folder: BotFolder, placeholderView: UIView) {
        self.dragInteraction = dragInteraction
        self.folder = folder
        self.item = folder
        self.placeholderView = placeholderView
    }
    
}
