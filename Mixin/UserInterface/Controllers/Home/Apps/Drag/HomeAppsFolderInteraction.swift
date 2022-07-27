import UIKit

protocol HomeAppsFolderInteraction {
    var dragInteraction: HomeAppsDragInteraction { get }
    var item: HomeAppItem { get }
    var isDismissing: Bool { get set }
    var wrapperView: UIView { get }
}

final class HomeAppsFolderCreationInteraction: HomeAppsFolderInteraction {
    
    let dragInteraction: HomeAppsDragInteraction
    let item: HomeAppItem
    let wrapperView: UIView
    let destinationApp: HomeApp
    
    var isDismissing = false
    
    init(dragInteraction: HomeAppsDragInteraction, destinationApp: HomeApp, wrapperView: UIView) {
        self.dragInteraction = dragInteraction
        self.destinationApp = destinationApp
        self.item = .app(destinationApp)
        self.wrapperView = wrapperView
    }
    
}

final class HomeAppsFolderDropInteraction: HomeAppsFolderInteraction {
    
    let dragInteraction: HomeAppsDragInteraction
    let item: HomeAppItem
    let wrapperView: UIView
    let folder: HomeAppFolder
    
    var isDismissing = false
    
    init(dragInteraction: HomeAppsDragInteraction, folder: HomeAppFolder, wrapperView: UIView) {
        self.dragInteraction = dragInteraction
        self.folder = folder
        self.item = .folder(folder)
        self.wrapperView = wrapperView
    }
    
}

final class HomeAppsOpenFolderInfo {
    
    let folder: HomeAppFolder
    let cell: AppFolderCell
    var isNewlyCreated: Bool
    var shouldCancelCreation = false
    
    init?(cell: AppFolderCell, isNewlyCreated: Bool) {
        guard let folder = cell.folder else {
            return nil
        }
        self.cell = cell
        self.folder = folder
        self.isNewlyCreated = isNewlyCreated
    }
    
}
