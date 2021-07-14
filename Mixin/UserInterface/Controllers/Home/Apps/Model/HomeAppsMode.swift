import Foundation

enum HomeAppsMode {
    
    case regular
    case pinned
    case folder
    case nestedFolder
    
    static let imageContainerSize = CGSize(width: 54, height: 54)
    static let folderRemovalInterval: TimeInterval = 0.5
    static let folderInterval: TimeInterval = 0.7
    static let pageInterval: TimeInterval = 0.7
    
    var sectionInset: UIEdgeInsets {
        switch self {
        case .regular:
            return UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        case .pinned:
            return UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        case .folder:
            return UIEdgeInsets(top: 32, left: 22, bottom: 32, right: 22)
        case .nestedFolder:
            return UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        }
    }
    
    var minimumInteritemSpacing: CGFloat {
        var margin: CGFloat = 0
        var totalWidth = AppDelegate.current.mainWindow.bounds.width
        switch self {
        case .regular:
            margin = 0
        case .pinned:
            margin = 20
        case .folder:
            margin = 44
        case .nestedFolder:
            margin = 0
            totalWidth = 54
        }
        let cellsWidth = itemSize.width * CGFloat(appsPerRow)
        let totalSpacing = totalWidth - margin * 2 - sectionInset.horizontal - cellsWidth
        return floor(totalSpacing / CGFloat(appsPerRow - 1))
    }
    
    var minimumLineSpacing: CGFloat {
        switch self {
        case .nestedFolder:
            return 2
        default:
            return 0
        }
    }
    
    var itemSize: CGSize {
        switch self {
        case .regular:
            return CGSize(width: 80, height: 100)
        case .pinned:
            return CGSize(width: 54, height: 54)
        case .folder:
            return CGSize(width: 80, height: 90)
        case .nestedFolder:
            return CGSize(width: 14, height: 14)
        }
    }
    
    var pageSize: CGSize {
        let screenWidth = AppDelegate.current.mainWindow.bounds.width
        switch self {
        case .regular:
            return CGSize(width: screenWidth, height: itemSize.height * CGFloat(rowsPerPage))
        case .pinned:
            return CGSize(width: screenWidth - 20 * 2, height: 82)
        case .folder:
            return CGSize(width: screenWidth - 44 * 2, height: 328)
        case .nestedFolder:
            return CGSize(width: 54, height: 54)
        }
    }
    
    var appsPerRow: Int {
        switch self {
        case .regular:
            return 4
        case .pinned:
            return 4
        case .folder:
            return 3
        case .nestedFolder:
            return 3
        }
    }
    
    var rowsPerPage: Int {
        switch self {
        case .regular:
            return (ScreenHeight.current == .medium ? 3 : 4)
        case .pinned:
            return 1
        case .folder:
            return 3
        case .nestedFolder:
            return 3
        }
    }
    
    var appsPerPage: Int {
        return rowsPerPage * appsPerRow
    }
    
}
