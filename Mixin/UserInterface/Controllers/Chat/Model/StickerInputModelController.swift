import UIKit
import MixinServices

class StickerInputModelController: NSObject {
    
    static let numberOfItemsPerRow = 3
    static let maxNumberOfRecentStickerRows = 6
    static let maxNumberOfRecentStickers = maxNumberOfRecentStickerRows * StickerInputModelController.numberOfItemsPerRow
    
    let recentStickersViewController = RecentStickersViewController(index: 0)
    let favoriteStickersViewController = FavoriteStickersViewController(index: 1)
    let giphyViewController = GiphyViewController(index: 2)
    let numberOfFixedControllers = 4
    
    private var officialStickers = [[StickerItem]]()
    
    private var reusableStickerViewControllers = Set<StickersViewController>()
    
    var initialViewController: StickersCollectionViewController? {
        if let vc = dequeueReusableStickersViewController(withIndex: 0), !vc.isEmpty {
            return vc
        } else {
            let index = officialStickers.isEmpty ? numberOfFixedControllers - 1 : numberOfFixedControllers
            return dequeueReusableStickersViewController(withIndex: index)
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
    
    func dequeueReusableStickersViewController(withIndex index: Int) -> StickersCollectionViewController? {
        guard index > 0 && index - numberOfFixedControllers < officialStickers.count else {
            return nil
        }
        switch index {
        case 1:
            return recentStickersViewController
        case 2:
            return favoriteStickersViewController
        case 3:
            return giphyViewController
        default:
            let viewController: StickersViewController
            if let vc = reusableStickerViewControllers.first(where: { $0.parent == nil }) {
                viewController = vc
            } else {
                viewController = StickersViewController()
                reusableStickerViewControllers.insert(viewController)
            }
            viewController.index = index
            viewController.load(stickers: officialStickers[index - numberOfFixedControllers])
            return viewController
        }
    }
    
}

extension StickerInputModelController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let index = (viewController as? StickersCollectionViewController)?.index {
            return dequeueReusableStickersViewController(withIndex: index - 1)
        } else {
            return nil
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let index = (viewController as? StickersCollectionViewController)?.index {
            return dequeueReusableStickersViewController(withIndex: index + 1)
        } else {
            return nil
        }
    }
    
}
