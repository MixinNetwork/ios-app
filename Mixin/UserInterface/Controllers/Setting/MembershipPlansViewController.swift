import UIKit
import StoreKit
import MixinServices

final class MembershipPlansViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var actionView: UIView!
    @IBOutlet weak var actionButton: StyledButton!
    @IBOutlet weak var verifyingPaymentLabel: UILabel!
    
    @IBOutlet weak var actionStackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var showActionViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideActionViewConstraint: NSLayoutConstraint!
    
    private let headerFooterReuseIdentifier = "h"
    
    private var selectedIndex: Int
    private var currentPlan: SafeMembership.Plan?
    private var pendingOrder: MembershipOrder?
    private var isPayingPendingOrder = false
    
    private var planDetails: [SafeMembership.PlanDetail] = []
    private var benefits: [[Benefit]] = Benefit.defaults()
    private var products: [String: Product] = [:] // Key is product.id
    
    private var selectedPlanDetails: SafeMembership.PlanDetail? {
        if !planDetails.isEmpty {
            planDetails[selectedIndex]
        } else {
            nil
        }
    }
    
    private var selectedBenefits: [Benefit] {
        if !benefits.isEmpty {
            benefits[selectedIndex]
        } else {
            []
        }
    }
    
    init(selectedPlan: SafeMembership.Plan?) {
        self.selectedIndex = if let selectedPlan {
            SafeMembership.Plan.allCases.firstIndex(of: selectedPlan) ?? 0
        } else {
            0
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.titleLabel.font = .scaledFont(ofSize: 18, weight: .semibold)
        titleView.titleLabel.text = R.string.localizable.mixin_one()
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, environment) in
            switch Section(rawValue: sectionIndex)! {
            case .planSelector:
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(133), heightDimension: .estimated(38))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(12), top: nil, trailing: .fixed(12), bottom: nil)
                let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(133), heightDimension: .estimated(38))
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 5, trailing: 4)
                section.orthogonalScrollingBehavior = .groupPaging
                return section
            case .introduction:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(223))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16)
                return section
            case .badge:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(88))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 16, bottom: 10, trailing: 16)
                return section
            case .benefits:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                if let benefits = self?.selectedBenefits, !benefits.isEmpty {
                    section.boundarySupplementaryItems = [
                        NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(14)),
                            elementKind: UICollectionView.elementKindSectionHeader,
                            alignment: .top
                        ),
                        NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(14)),
                            elementKind: UICollectionView.elementKindSectionFooter,
                            alignment: .bottom
                        ),
                    ]
                }
                return section
            }
        }
        collectionView.register(
            UICollectionReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: headerFooterReuseIdentifier
        )
        collectionView.register(
            UICollectionReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: headerFooterReuseIdentifier
        )
        collectionView.register(R.nib.membershipPlanSelectorCell)
        collectionView.register(R.nib.membershipPlanIntroductionCell)
        collectionView.register(R.nib.membershipPlanBadgeCell)
        collectionView.register(R.nib.membershipBenefitCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        let indexPath = IndexPath(item: selectedIndex, section: Section.planSelector.rawValue)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        verifyingPaymentLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        verifyingPaymentLabel.text = R.string.localizable.verifying_payment()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadCurrentPlan),
            name: LoginManager.accountDidChangeNotification,
            object: nil
        )
        reloadCurrentPlan()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadPendingOrder),
            name: MembershipOrderDAO.didUpdateNotification,
            object: nil
        )
        reloadPendingOrder()
        actionButton.style = .filled
        actionButton.applyDefaultContentInsets()
        actionButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        IAPTransactionObserver.global.onStatusChange = { [weak self] (observer) in
            self?.reloadBuyButtonTitle(observer: observer)
        }
        reloadBuyButtonTitle(observer: .global)
        reloadPlans()
    }
    
    @IBAction func performAction(_ sender: Any) {
        if let order = pendingOrder {
            view(order: order)
        } else {
            buy()
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func reloadCurrentPlan() {
        guard let account = LoginManager.shared.account else {
            return
        }
        DispatchQueue.main.async {
            self.currentPlan = if let plan = account.membership?.unexpiredPlan {
                SafeMembership.Plan(userMembershipPlan: plan)
            } else {
                nil
            }
            self.reloadBuyButtonTitle(observer: .global)
        }
    }
    
    @objc private func reloadPendingOrder() {
        DispatchQueue.global().async { [weak self] in
            let order = MembershipOrderDAO.shared.lastPendingOrder()
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.pendingOrder = order
                self.reloadBuyButtonTitle(observer: .global)
            }
        }
    }
    
    private func view(order: MembershipOrder) {
        guard let presentingViewController else {
            return
        }
        presentingViewController.dismiss(animated: true) {
            let viewController = MembershipOrderViewController(order: order)
            UIApplication.homeNavigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    private func buy() {
        guard let detail = selectedPlanDetails else {
            return
        }
        isPayingPendingOrder = true
        reloadBuyButtonTitle(observer: .global)
        let job = AddBotIfNotFriendJob(userID: BotUserID.mixinSafe)
        ConcurrentJobQueue.shared.addJob(job: job)
        Task { [products] in
            do {
                let order = try await SafeAPI.postMembershipOrder(detail: detail)
                MembershipOrderDAO.shared.save(orders: [order])
                guard let productID = order.fiatOrder?.subscriptionID else {
                    Logger.general.error(category: "Membership", message: "No fiat order")
                    await MainActor.run {
                        self.reloadBuyButtonTitle(observer: .global)
                    }
                    return
                }
                guard let product = products[productID] else {
                    Logger.general.error(category: "Membership", message: "No product: \(productID)")
                    await MainActor.run {
                        self.reloadBuyButtonTitle(observer: .global)
                    }
                    return
                }
                let result = try await product.purchase(options: [.appAccountToken(order.orderID)])
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        Logger.general.debug(category: "Membership", message: "Transaction verified: \(order.orderID)")
                        await IAPTransactionObserver.global.handle(transaction: transaction)
                    case .unverified:
                        Logger.general.debug(category: "Membership", message: "Transaction unverified: \(order.orderID)")
                        throw BuyingError.unverifiedTransaction
                    }
                case .userCancelled:
                    Logger.general.debug(category: "Membership", message: "User cancelled: \(order.orderID)")
                    let id = order.orderID.uuidString.lowercased()
                    let order = try await SafeAPI.cancelMembershipOrder(id: id)
                    MembershipOrderDAO.shared.save(orders: [order])
                    let reloadOrders = ReloadMembershipOrderJob()
                    ConcurrentJobQueue.shared.addJob(job: reloadOrders)
                case .pending:
                    // Leave it to AppDelegate
                    Logger.general.debug(category: "Membership", message: "Pending: \(order.orderID)")
                @unknown default:
                    break
                }
            } catch {
                await MainActor.run {
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
            await MainActor.run {
                self.isPayingPendingOrder = false
                self.reloadBuyButtonTitle(observer: .global)
            }
        }
    }
    
}

extension MembershipPlansViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .planSelector:
            SafeMembership.Plan.allCases.count
        case .introduction, .badge:
            1
        case .benefits:
            selectedBenefits.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .planSelector:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.membership_plan_selector, for: indexPath)!
            let plan = SafeMembership.Plan.allCases[indexPath.item]
            cell.load(plan: plan)
            return cell
        case .introduction:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.membership_plan_introduction, for: indexPath)!
            let plan = selectedPlanDetails?.plan ?? SafeMembership.Plan.allCases[selectedIndex]
            cell.load(plan: plan)
            return cell
        case .badge:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.membership_plan_badge, for: indexPath)!
            let plan = selectedPlanDetails?.plan ?? SafeMembership.Plan.allCases[selectedIndex]
            cell.load(plan: plan)
            return cell
        case .benefits:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.membership_benefit, for: indexPath)!
            let benefit = selectedBenefits[indexPath.item]
            cell.imageView.image = benefit.icon
            cell.titleLabel.text = benefit.title
            cell.descriptionLabel.attributedText = benefit.description
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: headerFooterReuseIdentifier,
            for: indexPath
        )
        view.backgroundColor = R.color.background()
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        view.layer.maskedCorners = if kind == UICollectionView.elementKindSectionHeader {
            [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else {
            [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        return view
    }
    
}

extension MembershipPlansViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .planSelector:
            self.selectedIndex = indexPath.item
            reload(sections: [.introduction, .badge, .benefits])
            reloadBuyButtonTitle(observer: .global)
        case .introduction, .badge, .benefits:
            break
        }
    }
    
}

extension MembershipPlansViewController {
    
    private enum Section: Int, CaseIterable {
        case planSelector
        case introduction
        case badge
        case benefits
    }
    
    private enum BuyingError: Error {
        case unverifiedTransaction
    }
    
    private struct Benefit {
        
        let icon: UIImage
        let title: String
        let description: NSAttributedString
        
        init(icon: UIImage, title: String, description: String, highlights: [String]) {
            let attributedDescription = NSMutableAttributedString(
                string: description,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .footnote),
                    .foregroundColor: R.color.text_tertiary()!
                ]
            )
            let nsDescription = attributedDescription.string as NSString
            for highlight in highlights {
                var searchRange = NSRange(location: 0, length: nsDescription.length)
                var foundRange = NSRange(location: NSNotFound, length: 0)
                while searchRange.location < nsDescription.length {
                    searchRange.length = nsDescription.length - searchRange.location
                    foundRange = nsDescription.range(of: highlight, options: .literal, range: searchRange)
                    if foundRange.location == NSNotFound {
                        break
                    } else {
                        attributedDescription.setAttributes(
                            [
                                .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 13, weight: .medium)),
                                .foregroundColor: R.color.text()!
                            ],
                            range: foundRange
                        )
                        searchRange.location = foundRange.location+foundRange.length
                    }
                }
            }
            
            self.icon = icon
            self.title = title
            self.description = NSAttributedString(attributedString: attributedDescription)
        }
        
        static func defaults() -> [[Benefit]] {
            [
                SafeMembership.PlanDetail(
                    plan: .basic,
                    accountQuota: 2,
                    transactionQuota: 2,
                    accountantsQuota: 3,
                    membersQuota: 3,
                    amount: "100",
                    discountAmount: "100",
                    paymentAmount: "100",
                    appleSubscriptionID: ""
                ),
                SafeMembership.PlanDetail(
                    plan: .standard,
                    accountQuota: 5,
                    transactionQuota: 5,
                    accountantsQuota: 5,
                    membersQuota: 10,
                    amount: "1000",
                    discountAmount: "1000",
                    paymentAmount: "1000",
                    appleSubscriptionID: ""
                ),
                SafeMembership.PlanDetail(
                    plan: .premium,
                    accountQuota: 100,
                    transactionQuota: 20,
                    accountantsQuota: 10,
                    membersQuota: 100,
                    amount: "10000",
                    discountAmount: "10000",
                    paymentAmount: "10000",
                    appleSubscriptionID: ""
                ),
            ].map(Benefit.benefits(detail:))
        }
        
        static func benefits(detail: SafeMembership.PlanDetail) -> [Benefit] {
            var benefits = [
                Benefit(
                    icon: R.image.membership_benefit_safe()!,
                    title: .mixinSafe,
                    description: R.string.localizable.membership_benefit_create_safe(detail.accountQuota),
                    highlights: [
                        NSNumber(value: detail.accountQuota).description(withLocale: Locale.current),
                    ]
                ),
                Benefit(
                    icon: R.image.membership_benefit_star()!,
                    title: .mixinStar,
                    description: R.string.localizable.membership_benefit_get_stars(detail.transactionQuota),
                    highlights: [
                        NSNumber(value: detail.transactionQuota).description(withLocale: Locale.current),
                    ]
                ),
                Benefit(
                    icon: R.image.membership_benefit_members()!,
                    title: R.string.localizable.safe_members(),
                    description: R.string.localizable.membership_benefit_safe_members(detail.accountantsQuota, detail.membersQuota),
                    highlights: [
                        NSNumber(value: detail.accountantsQuota).description(withLocale: Locale.current),
                        NSNumber(value: detail.membersQuota).description(withLocale: Locale.current),
                    ]
                ),
            ]
            switch detail.plan {
            case .basic:
                let recoveryFee = NSDecimalNumber(decimal: 2)
                benefits.append(
                    Benefit(
                        icon: R.image.membership_benefit_recovery()!,
                        title: R.string.localizable.paid_recovery_service(),
                        description: R.string.localizable.membership_benefit_paid_recovery_service(recoveryFee.intValue),
                        highlights: [
                            recoveryFee.description(withLocale: Locale.current),
                        ]
                    )
                )
            case .standard, .premium:
                benefits.append(
                    Benefit(
                        icon: R.image.membership_benefit_recovery()!,
                        title: R.string.localizable.free_recovery_service(),
                        description: R.string.localizable.membership_benefit_free_recovery_service(),
                        highlights: []
                    )
                )
            }
            return benefits
        }
        
    }
    
    private func reload(sections: [Section]) {
        let set = IndexSet(sections.map(\.rawValue))
        UIView.performWithoutAnimation {
            collectionView.reloadSections(set)
        }
    }
    
    private func reloadPlans() {
        SafeAPI.membershipPlans { [weak self] result in
            switch result {
            case let .success(membership):
                self?.reloadData(membership: membership)
            case let .failure(error):
                Logger.general.debug(category: "Membership", message: "\(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    self?.reloadPlans()
                }
            }
        }
    }
    
    private func reloadData(membership: SafeMembership) {
        planDetails = membership.plans
        benefits = membership.plans.map(Benefit.benefits(detail:))
        reload(sections: [.introduction, .badge, .benefits])
        Task { [weak self] in
            let productIDs = membership.plans.map(\.appleSubscriptionID)
            let products = try await Product.products(for: productIDs)
                .reduce(into: [:]) { result, product in
                    result[product.id] = product
                }
            await MainActor.run {
                guard let self else {
                    return
                }
                self.products = products
                self.reloadBuyButtonTitle(observer: .global)
            }
        }
    }
    
    private func hideActionView() {
        hideActionViewConstraint.priority = .almostRequired
        showActionViewConstraint.priority = .almostInexist
        actionView.isHidden = true
    }
    
    private func showActionView(showVerifyPaymentLabel: Bool) {
        hideActionViewConstraint.priority = .almostInexist
        showActionViewConstraint.priority = .almostRequired
        actionView.isHidden = false
        if showVerifyPaymentLabel {
            verifyingPaymentLabel.isHidden = false
            actionStackViewBottomConstraint.constant = 10
        } else {
            verifyingPaymentLabel.isHidden = true
            actionStackViewBottomConstraint.constant = 20
        }
    }
    
    private func reloadBuyButtonTitle(observer: IAPTransactionObserver) {
        if isPayingPendingOrder {
            showActionView(showVerifyPaymentLabel: false)
            actionButton.isBusy = true
        } else if let order = pendingOrder, order.status.knownCase == .initial {
            showActionView(showVerifyPaymentLabel: true)
            actionButton.setTitle(R.string.localizable.view_invoice(), for: .normal)
            actionButton.isEnabled = true
            actionButton.isBusy = false
        } else {
            if planDetails.isEmpty, let currentPlan, SafeMembership.Plan.allCases[selectedIndex] < currentPlan {
                hideActionView()
            } else if observer.isRunning {
                showActionView(showVerifyPaymentLabel: false)
                actionButton.setTitle(R.string.localizable.upgrading_plan(), for: .normal)
                actionButton.isEnabled = false
                actionButton.isBusy = false
            } else if let detail = selectedPlanDetails {
                if detail.plan == currentPlan {
                    showActionView(showVerifyPaymentLabel: false)
                    actionButton.setTitle(R.string.localizable.current_plan(), for: .normal)
                    actionButton.isEnabled = false
                    actionButton.isBusy = false
                } else if let currentPlan, detail.plan < currentPlan {
                    hideActionView()
                } else if let product = products[detail.appleSubscriptionID] {
                    showActionView(showVerifyPaymentLabel: false)
                    let title = R.string.localizable.upgrade_plan_for(product.displayPrice)
                    actionButton.setTitle(title, for: .normal)
                    actionButton.isEnabled = true
                    actionButton.isBusy = false
                } else {
                    showActionView(showVerifyPaymentLabel: false)
                    actionButton.setTitle(R.string.localizable.coming_soon(), for: .normal)
                    actionButton.isEnabled = false
                    actionButton.isBusy = false
                }
            } else {
                showActionView(showVerifyPaymentLabel: false)
                actionButton.setTitle(" ", for: .normal)
                actionButton.isEnabled = false
                actionButton.isBusy = true
            }
        }
    }
    
}
