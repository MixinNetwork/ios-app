import UIKit

final class PerpPositionAdjustmentSelectorViewController: UIViewController {
    
    struct Adjustment {
        let target: PerpPositionAdjustmentTarget
        let behavior: Behavior
    }
    
    enum Behavior: Int, CaseIterable {
        case increase
        case decrease
    }
    
    private enum Section {
        case margin
        case position
        case introduction
    }
    
    var onSelected: ((Adjustment) -> Void)?
    
    private let sections: [Section] = [.margin, .position, .introduction]
    private let titleViewHeight: CGFloat = 70
    
    private weak var collectionView: UICollectionView!
    
    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_secondary()
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        
        let titleView = PopupTitleView()
        titleView.backgroundColor = R.color.background_secondary()
        titleView.titleLabel.text = R.string.localizable.perps_adjust_title()
        view.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(titleViewHeight)
        }
        titleView.closeButton.addTarget(
            self,
            action: #selector(close(_:)),
            for: .touchUpInside
        )
        
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, _) in
            switch self?.sections[sectionIndex] {
            case .none, .margin, .position:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(82))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [
                    NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .estimated(34),
                        ),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top,
                    ),
                ]
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16)
                section.interGroupSpacing = 8
                return section
            case .introduction:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(213))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 28, bottom: 40, trailing: 28)
                return section
            }
        }
        let collectionView = UICollectionView(
            frame: CGRect(
                x: 0,
                y: titleViewHeight,
                width: view.bounds.width,
                height: view.bounds.height - titleViewHeight
            ),
            collectionViewLayout: layout
        )
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.isScrollEnabled = true
        collectionView.alwaysBounceVertical = false
        view.addSubview(collectionView)
        self.collectionView = collectionView
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        collectionView.register(R.nib.addWalletMethodCell)
        collectionView.register(R.nib.perpPositionAdjustmentIntroductionCell)
        collectionView.register(
            HeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: HeaderView.reuseIdentifier,
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.layoutIfNeeded()
        let contentHeight = titleViewHeight
            + collectionView.contentSize.height
            + collectionView.adjustedContentInset.vertical
        let containerHeight = presentationController?.containerView?.bounds.height
            ?? presentingViewController?.view.bounds.height
            ?? view.bounds.height
        let height = min(contentHeight, containerHeight - view.windowSafeAreaInsets.top)
        if abs(preferredContentSize.height - height) > 0.5 {
            preferredContentSize.height = height
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}

extension PerpPositionAdjustmentSelectorViewController: UICollectionViewDataSource {
    
    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath,
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: HeaderView.reuseIdentifier,
            for: indexPath,
        ) as! HeaderView
        header.titleLabel.text = switch sections[indexPath.section] {
        case .margin:
            R.string.localizable.margin()
        case .position:
            R.string.localizable.position()
        case .introduction:
            nil
        }
        return header
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .margin:
            Behavior.allCases.count
        case .position:
            1
        case .introduction:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .margin:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.add_wallet_method, for: indexPath)!
            switch Behavior.allCases[indexPath.row] {
            case .increase:
                cell.iconImageView.image = R.image.increase_margin()
                cell.titleLabel.text = R.string.localizable.perps_add_margin()
                cell.subtitleLabel.text = R.string.localizable.perps_add_margin_description()
            case .decrease:
                cell.iconImageView.image = R.image.decrease_margin()
                cell.titleLabel.text = R.string.localizable.perps_reduce_margin()
                cell.subtitleLabel.text = R.string.localizable.perps_reduce_margin_description()
            }
            return cell
        case .position:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.add_wallet_method, for: indexPath)!
            cell.iconImageView.image = R.image.increase_position()
            cell.titleLabel.text = R.string.localizable.perps_add_to_position()
            cell.subtitleLabel.text = R.string.localizable.perps_add_position_description()
            return cell
        case .introduction:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perp_position_adjustment_introduction, for: indexPath)!
        }
    }
    
}

extension PerpPositionAdjustmentSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let target: PerpPositionAdjustmentTarget
        let behavior: Behavior
        switch sections[indexPath.section] {
        case .margin:
            target = .margin
            behavior = Behavior.allCases[indexPath.row]
        case .position:
            target = .position
            behavior = .increase
        case .introduction:
            return
        }
        let adjustment = Adjustment(target: target, behavior: behavior)
        presentingViewController?.dismiss(animated: true) { [onSelected] in
            onSelected?(adjustment)
        }
    }
    
}

extension PerpPositionAdjustmentSelectorViewController {
    
    private final class HeaderView: UICollectionReusableView {
        
        static let reuseIdentifier = "header"
        
        let titleLabel = UILabel()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadLabel()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadLabel()
        }
        
        private func loadLabel() {
            titleLabel.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true,
            )
            titleLabel.textColor = R.color.text_secondary()
            titleLabel.numberOfLines = 0
            titleLabel.accessibilityTraits.insert(.header)
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(7)
                make.leading.trailing.equalToSuperview().inset(4)
                make.bottom.equalToSuperview().inset(10)
            }
        }
        
    }
    
}
