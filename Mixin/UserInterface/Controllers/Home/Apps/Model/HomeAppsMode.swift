import UIKit

enum HomeAppsMode {
    
    static let imageContainerSize = CGSize(width: 54, height: 54)
    
    case regular
    case pinned
    case folder
    case nestedFolder
    
    var sectionInset: UIEdgeInsets {
        switch self {
        case .regular:
            return UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        case .pinned:
            let rightInset: CGFloat = {
                let totalWidth = AppDelegate.current.mainWindow.bounds.width
                let cellsWidth = itemSize.width * 4
                let leftInset: CGFloat = 20
                let totalSpacing = totalWidth - margin * 2 - leftInset * 2 - cellsWidth
                return totalSpacing / CGFloat(appsPerRow) + Self.imageContainerSize.width + margin
            }()
            return UIEdgeInsets(top: 14, left: 20, bottom: 14, right: rightInset)
        case .folder:
            return UIEdgeInsets(top: 32, left: 22, bottom: 32, right: 22)
        case .nestedFolder:
            return UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        }
    }
    
    var minimumInteritemSpacing: CGFloat {
        var totalWidth = AppDelegate.current.mainWindow.bounds.width
        if self == .nestedFolder {
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
        case .folder:
            return 20
        case .regular, .pinned:
            return 0
        }
    }
    
    var itemSize: CGSize {
        switch self {
        case .regular:
            if ScreenWidth.current <= .short {
                return CGSize(width: 60, height: 96)
            } else {
                return CGSize(width: 80, height: 100)
            }
        case .pinned:
            return CGSize(width: 54, height: 54)
        case .folder:
            if ScreenWidth.current <= .short {
                return CGSize(width: 60, height: 74)
            } else {
                return CGSize(width: 80, height: 74)
            }
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
            return CGSize(width: screenWidth - margin * 2, height: 82)
        case .folder:
            return CGSize(width: screenWidth - margin * 2, height: 328)
        case .nestedFolder:
            return CGSize(width: 54, height: 54)
        }
    }
    
    var appsPerRow: Int {
        switch self {
        case .regular:
            return 4
        case .pinned:
            return 3
        case .folder:
            return 3
        case .nestedFolder:
            return 3
        }
    }
    
    var rowsPerPage: Int {
        switch self {
        case .regular:
            return (ScreenHeight.current <= .medium ? 3 : 4)
        case .pinned:
            return 1
        case .folder:
            return 3
        case .nestedFolder:
            return 3
        }
    }
    
    var appsPerPage: Int {
        rowsPerPage * appsPerRow
    }
    
    private var margin: CGFloat {
        switch self {
        case .regular:
            return 0
        case .pinned:
            return 20
        case .folder:
            if ScreenWidth.current <= .short {
                return 20
            } else {
                return 44
            }
        case .nestedFolder:
            return 0
        }
    }
    
}
