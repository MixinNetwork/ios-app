import UIKit
import MixinServices

class StickerInputModelController: NSObject {
    
    static let numberOfItemsPerRow = 3
    static let maxNumberOfRecentStickerRows = 6
    static let maxNumberOfRecentStickers = maxNumberOfRecentStickerRows * StickerInputModelController.numberOfItemsPerRow
    
    let recentStickersViewController = RecentStickersViewController(index: 1)
    let favoriteStickersViewController = FavoriteStickersViewController(index: 2)
    let giphyViewController = GiphyViewController(index: 3)
    let numberOfFixedControllers = 4
    
    private var addedStickers = [[StickerItem]]()
    
    private var reusableStickerViewControllers = Set<StickersViewController>()
    
    var initialViewController: StickersCollectionViewController? {
        if let vc = dequeueReusableStickersViewController(withIndex: 1), !vc.isEmpty {
            return vc
        } else {
            let index = addedStickers.isEmpty ? numberOfFixedControllers - 1 : numberOfFixedControllers
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
    
    func reloadAddedStickers(stickers: [[StickerItem]]) {
        addedStickers = stickers
    }
    
    func dequeueReusableStickersViewController(withIndex index: Int) -> StickersCollectionViewController? {
        guard index > 0 && index - numberOfFixedControllers < addedStickers.count else {
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
            viewController.load(stickers: addedStickers[index - numberOfFixedControllers])
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
