import UIKit
import MixinServices

final class DepositLinkPreviewViewController: UIViewController {
    
    private let link: DepositLink
    
    init(link: DepositLink) {
        self.link = link
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_title_close(),
            target: self,
            action: #selector(close(_:))
        )
        
        view.backgroundColor = R.color.background()
        let scrollView = UIScrollView()
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        let contentView = UIView()
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        
        let linkView = DepositLinkView()
        contentView.addSubview(linkView)
        linkView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
                .inset(UIEdgeInsets(top: 54, left: 20, bottom: 0, right: 20))
        }
        linkView.size = .medium
        linkView.load(link: link)
        
        let actionView = R.nib.authenticationPreviewDoubleButtonTrayView(withOwner: nil)!
        view.addSubview(actionView)
        actionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(scrollView.snp.bottom)
        }
        switch link.chain {
        case .mixin:
            actionView.leftButton.setTitle(R.string.localizable.share(), for: .normal)
            actionView.leftButton.addTarget(self, action: #selector(share(_:)), for: .touchUpInside)
            actionView.rightButton.setTitle(R.string.localizable.forward(), for: .normal)
            actionView.rightButton.addTarget(self, action: #selector(forward(_:)), for: .touchUpInside)
        case .native:
            actionView.leftButton.setTitle(R.string.localizable.copy_link(), for: .normal)
            actionView.leftButton.addTarget(self, action: #selector(copyLink(_:)), for: .touchUpInside)
            actionView.rightButton.setTitle(R.string.localizable.share(), for: .normal)
            actionView.rightButton.addTarget(self, action: #selector(share(_:)), for: .touchUpInside)
        }
    }
    
    @objc private func close(_ sender: Any) {
        navigationController?.presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func copyLink(_ sender: Any) {
        UIPasteboard.general.string = link.textValue
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
    @objc private func share(_ sender: Any) {
        let share = ShareDepositLinkViewController(link: link)
        present(share, animated: true)
    }
    
    @objc private func forward(_ sender: Any) {
        guard
            case let .mixin(context) = link.chain,
            let specification = context.specification
        else {
            return
        }
        let amount = CurrencyFormatter.localizedString(
            from: specification.amount,
            format: .precision,
            sign: .never,
            symbol: .custom(specification.token.symbol)
        )
        let account = context.account
        let content = AppCardData.V1Content(
            appID: BotUserID.mixinRoute,
            cover: nil,
            title: R.string.localizable.mixin_payment_title(),
            description: R.string.localizable.mixin_payment_content(
                amount,
                specification.token.depositNetworkName ?? "",
                "\(account.fullName)(\(account.identityNumber))",
            ),
            actions: [
                .init(action: link.textValue, color: "#4B7CDD", label: R.string.localizable.pay_now())
            ],
            updatedAt: nil,
            isShareable: true
        )
        navigationController?.presentingViewController?.dismiss(animated: true) {
            let receiverSelector = MessageReceiverViewController.instance(content: .appCard(.v1(content)))
            UIApplication.homeNavigationController?.pushViewController(receiverSelector, animated: true)
        }
    }
    
}
