import UIKit

class StickerInputModelController: NSObject {
    
    static let numberOfItemsPerRow = 3
    static let maxNumberOfRecentStickerRows = 6
    static let maxNumberOfRecentStickers = maxNumberOfRecentStickerRows * StickerInputModelController.numberOfItemsPerRow
    
    let recentStickersViewController = RecentStickersViewController(index: 0)
    let favoriteStickersViewController = FavoriteStickersViewController(index: 1)
    
    private var officialStickers = [[Sticker]]()
    
    private var reusableStickerViewControllers = Set<StickersViewController>()
    
    var initialViewController: StickersViewController? {
        if let vc = dequeueReusableStickersViewController(withIndex: 0), !vc.stickers.isEmpty {
            return vc
        } else {
            return dequeueReusableStickersViewController(withIndex: 2)
        }
    }
    
    func reloadRecentFavoriteStickers() {
        let limit = StickerInputModelController.maxNumberOfRecentStickers
        let recentStickers = StickerDAO.shared.recentUsedStickers(limit: limit)
        let favoriteStickers = StickerDAO.shared.getFavoriteStickers()
        DispatchQueue.main.async {
            self.recentStickersViewController.load(stickers: recentStickers)
            self.favoriteStickersViewController.load(stickers: favoriteStickers)
        }
    }
    
    func reloadOfficialStickers(albums: [Album]) {
        officialStickers = albums.map{ StickerDAO.shared.getStickers(albumId: $0.albumId) }
    }
    
    func dequeueReusableStickersViewController(withIndex index: Int) -> StickersViewController? {
        guard index >= 0 && index - 2 < officialStickers.count else {
            return nil
        }
        switch index {
        case 0:
            return recentStickersViewController
        case 1:
            return favoriteStickersViewController
        default:
            let viewController: StickersViewController
            if let vc = reusableStickerViewControllers.first(where: { $0.parent == nil }) {
                viewController = vc
            } else {
                viewController = StickersViewController()
                reusableStickerViewControllers.insert(viewController)
            }
            viewController.index = index
            viewController.load(stickers: officialStickers[index - 2])
            return viewController
        }
    }
    
}

extension StickerInputModelController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let index = (viewController as? StickersViewController)?.index {
            return dequeueReusableStickersViewController(withIndex: index - 1)
        } else {
            return nil
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let index = (viewController as? StickersViewController)?.index {
            return dequeueReusableStickersViewController(withIndex: index + 1)
        } else {
            return nil
        }
    }
    
}
