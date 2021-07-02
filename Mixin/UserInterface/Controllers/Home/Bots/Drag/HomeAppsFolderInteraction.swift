import Foundation

protocol HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction { get set }
    var item: BotItem { get set }
    var isDismissing: Bool { get set }
    var wrapperView: UIView { get set }
    
}

class HomeAppsFolderCreationInteraction: HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction
    var destinationApp: Bot
    var wrapperView: UIView
    var isDismissing: Bool = false
    
    var item: BotItem
    
    required init(dragInteraction: HomeAppsDragInteraction, destinationApp: Bot, wrapperView: UIView) {
        self.dragInteraction = dragInteraction
        self.destinationApp = destinationApp
        self.item = destinationApp
        self.wrapperView = wrapperView
    }
    
}

class HomeAppsFolderDropInteraction: HomeAppsFolderInteraction {
    
    var dragInteraction: HomeAppsDragInteraction
    var folder: BotFolder
    var wrapperView: UIView
    var isDismissing: Bool = false
    
    var item: BotItem
    
    required init(dragInteraction: HomeAppsDragInteraction, folder: BotFolder, wrapperView: UIView) {
        self.dragInteraction = dragInteraction
        self.folder = folder
        self.item = folder
        self.wrapperView = wrapperView
    }
    
}

class HomeAppsOpenFolderInfo {
    
    var folder: BotFolder
    var cell: BotFolderCell
    var isNewFolder: Bool
    var shouldCancelCreation = false
    
    required init(cell: BotFolderCell, isNewFolder: Bool) {
        self.cell = cell
        self.folder = cell.item as! BotFolder
        self.isNewFolder = isNewFolder
    }
    
}
