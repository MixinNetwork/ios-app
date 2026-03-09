import UIKit
import MixinServices

final class AllPerpetualPositionsViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    private let wallet: Wallet
    private let initialContent: PerpetualPositionType
    
    private weak var contentViewController: AllPerpetualPositionsContentViewController?
    
    init(wallet: Wallet, content: PerpetualPositionType) {
        self.wallet = wallet
        self.initialContent = content
        let nib = R.nib.allPerpetualPositionsView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "All Positions"
        collectionView.register(R.nib.exploreSegmentCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        if let item = PerpetualPositionType.allCases.firstIndex(of: initialContent) {
            collectionView.selectItem(
                at: IndexPath(item: item, section: 0),
                animated: true,
                scrollPosition: []
            )
        }
        load(content: initialContent)
    }
    
    private func load(content: PerpetualPositionType) {
        if let content = contentViewController {
            content.willMove(toParent: nil)
            content.view.removeFromSuperview()
            content.removeFromParent()
        }
        
        let contentViewController = AllPerpetualPositionsContentViewController(
            wallet: wallet,
            content: content
        )
        addChild(contentViewController)
        view.addSubview(contentViewController.view)
        contentViewController.view.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(collectionView.snp.bottom).offset(9)
        }
        contentViewController.didMove(toParent: self)
        self.contentViewController = contentViewController
    }
    
}

extension AllPerpetualPositionsViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AllPerpetualPositionsViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        PerpetualPositionType.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
        cell.label.text = switch PerpetualPositionType(rawValue: indexPath.item)! {
        case .open:
            "Open Positions"
        case .closed:
            "Closed Positions"
        }
        return cell
    }
    
}

extension AllPerpetualPositionsViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let content = PerpetualPositionType(rawValue: indexPath.item)!
        load(content: content)
    }
    
}
