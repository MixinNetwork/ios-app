import UIKit
import SwiftUI

final class ManualViewController: UIViewController {
    
    struct Page {
        
        let title: String
        let view: AnyView
        
        init<Content: View>(title: String, view: Content) {
            self.title = title
            self.view = AnyView(view)
        }
        
    }
    
    private let pages: [Page]
    
    private var reusableContentViewControllers: Set<ManualPageContentViewController> = []
    
    private weak var titleView: PopupTitleView!
    private weak var pageSelectorCollectionView: UICollectionView!
    private weak var pageViewController: UIPageViewController!
    
    init(pages: [Page]) {
        self.pages = pages
        super.init(nibName: nil, bundle: nil)
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
        view.backgroundColor = R.color.background_secondary()
        
        let titleView = PopupTitleView()
        view.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(70)
        }
        titleView.titleLabel.text = title
        self.titleView = titleView
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        
        let layout = {
            let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(56), heightDimension: .absolute(38))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 20, bottom: 3, trailing: 20)
            let config = UICollectionViewCompositionalLayoutConfiguration()
            config.scrollDirection = .horizontal
            return UICollectionViewCompositionalLayout(section: section, configuration: config)
        }()
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 70, width: view.bounds.width, height: 44),
            collectionViewLayout: layout
        )
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleView.snp.bottom).offset(-3)
            make.height.equalTo(44)
        }
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(R.nib.exploreSegmentCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        pageSelectorCollectionView = collectionView
        
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
        self.pageViewController = pageViewController
        
        if let firstPage = dequeueReusableViewController(of: 0) {
            pageSelectorCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: [])
            pageViewController.setViewControllers([firstPage], direction: .forward, animated: false)
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    private func dequeueReusableViewController(of index: Int) -> ManualPageContentViewController? {
        guard index >= 0 && index < pages.count else {
            return nil
        }
        let page = pages[index]
        let previousTitle: String? = if index > 0 {
            pages[index - 1].title
        } else {
            nil
        }
        let nextTitle: String? = if index < pages.count - 1 {
            pages[index + 1].title
        } else {
            R.string.localizable.start()
        }
        let viewController: ManualPageContentViewController
        if let controller = reusableContentViewControllers.first(where: \.isReusable) {
            viewController = controller
            viewController.load(
                index: index,
                page: page,
                previousTitle: previousTitle,
                nextTitle: nextTitle
            )
        } else {
            let controller = ManualPageContentViewController(
                index: index,
                page: page,
                previousTitle: previousTitle,
                nextTitle: nextTitle
            )
            controller.delegate = self
            reusableContentViewControllers.insert(controller)
            viewController = controller
        }
        return viewController
    }
    
}

extension ManualViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
        cell.label.text = pages[indexPath.item].title
        return cell
    }
    
}

extension ManualViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let page = dequeueReusableViewController(of: indexPath.item) else {
            return
        }
        if let focus = pageViewController.viewControllers?.first as? ManualPageContentViewController {
            pageViewController.setViewControllers(
                [page],
                direction: page.index > focus.index ? .forward : .reverse,
                animated: true
            )
        } else {
            pageViewController.setViewControllers([page], direction: .forward, animated: false)
        }
    }
    
}

extension ManualViewController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewController = viewController as? ManualPageContentViewController else {
            return nil
        }
        return dequeueReusableViewController(of: viewController.index - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewController = viewController as? ManualPageContentViewController else {
            return nil
        }
        return dequeueReusableViewController(of: viewController.index + 1)
    }
    
}

extension ManualViewController: UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard let focus = pageViewController.viewControllers?.first as? ManualPageContentViewController else {
            return
        }
        let indexPath = IndexPath(item: focus.index, section: 0)
        pageSelectorCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
    }
    
}

extension ManualViewController: ManualPageContentViewController.Delegate {
    
    func manualPageContentViewController(_ controller: ManualPageContentViewController, didNavigateTo index: Int) {
        if index == pages.count {
            presentingViewController?.dismiss(animated: true)
        } else {
            pageSelectorCollectionView.selectItem(
                at: IndexPath(item: index, section: 0),
                animated: false,
                scrollPosition: .left
            )
            if let page = dequeueReusableViewController(of: index) {
                pageViewController.setViewControllers(
                    [page],
                    direction: page.index > controller.index ? .forward : .reverse,
                    animated: true
                )
            }
        }
    }
    
}
