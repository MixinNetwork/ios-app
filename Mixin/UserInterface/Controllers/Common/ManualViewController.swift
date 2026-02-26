import UIKit
import SwiftUI

final class ManualViewController: UIViewController {
    
    private let pages: [Page]
    
    private var reusablePageContentViewControllers: Set<PageContentViewController> = []
    
    private weak var titleView: PopupTitleView!
    private weak var pageViewController: UIPageViewController!
    
    init(pages: [Page]) {
        self.pages = pages
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override var title: String? {
        didSet {
            if isViewLoaded {
                titleView.titleLabel.text = title
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleView = PopupTitleView()
        view.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(70)
        }
        titleView.titleLabel.text = title
        self.titleView = titleView
        
        let layout = {
            let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(56), heightDimension: .absolute(38))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 20, bottom: 3, trailing: 20)
            return UICollectionViewCompositionalLayout(section: section)
        }()
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 70, width: view.bounds.width, height: 44),
            collectionViewLayout: layout
        )
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleView.snp.bottom).offset(-3)
        }
        
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
        )
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(collectionView.snp.bottom).offset(9)
        }
        pageViewController.didMove(toParent: self)
        pageViewController.dataSource = self
        pageViewController.delegate = self
        
    }
    
    private func dequeueReusableViewController(of index: Int) -> PageContentViewController? {
        guard index >= 0 && index < pages.count else {
            return nil
        }
        let page = pages[index]
        let viewController: PageContentViewController
        if let vc = reusablePageContentViewControllers.first(where: \.isReusable) {
            viewController = vc
        } else {
            let vc = PageContentViewController()
            reusablePageContentViewControllers.insert(vc)
            viewController = vc
        }
        
        return viewController
    }
    
}

extension ManualViewController {
    
    struct Page {
        let title: String
        let view: any View
    }
    
    private final class PageContentViewController: UIViewController {
        
        var isReusable: Bool {
            parent == nil
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
        }
        
        func load(index: Int, previousTitle: String?, nextTitle: String?, page: Page) {
            
        }
        
    }
    
}

extension ManualViewController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        nil
    }
    
}

extension ManualViewController: UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        let focus = pageViewController.viewControllers?.first as? PageContentViewController
    }
    
}
