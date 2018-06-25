import Foundation
import UIKit
import Alamofire

class UrlWindow: BottomSheetView {

    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var containerView: UIView!

    @IBOutlet weak var contentHeightConstraint: NSLayoutConstraint!

    private var animationPushOriginPoint: CGPoint {
        return CGPoint(x: self.bounds.size.width + self.popupView.bounds.size.width, y: self.popupView.center.y)
    }
    private var animationPushEndPoint: CGPoint {
        return CGPoint(x: self.bounds.size.width-(self.popupView.bounds.size.width * 0.5), y: self.popupView.center.y)
    }

    private lazy var groupView = GroupView.instance()
    private lazy var loginView = LoginView.instance()
    private lazy var payView = PayView.instance()
    private lazy var userView = UserView.instance()

    private(set) var fromWeb = false
    private var showLoginView = false
    private var interceptDismiss = false

    class func checkUrl(url: URL, fromWeb: Bool = false, clearNavigationStack: Bool = true, checkLastWindow: Bool = true) -> Bool {
        if checkLastWindow && UIApplication.shared.keyWindow?.subviews.last is UrlWindow {
            return false
        }
        guard let mixinURL = MixinURL(url: url) else {
            return false
        }
        switch mixinURL {
        case let .codes(code):
            return checkCodesUrl(code, fromWeb: fromWeb, clearNavigationStack: clearNavigationStack)
        case .pay:
            return checkPayUrl(url: url, fromWeb: fromWeb)
        case let .users(id):
            return checkUsersUrl(id, fromWeb: fromWeb, clearNavigationStack: clearNavigationStack)
        case let .transfer(id):
            return checkTransferUrl(id, fromWeb: fromWeb, clearNavigationStack: clearNavigationStack)
        case .send:
            return checkSendUrl(url: url, fromWeb: fromWeb)
        case .unknown:
            return false
        }
    }

    override func presentPopupControllerAnimated() {
        if fromWeb {
            contentHeightConstraint.constant = 484
            self.layoutIfNeeded()
            windowBackgroundColor = UIColor.clear
        }
        super.presentPopupControllerAnimated()
        loadingView.startAnimating()
        loadingView.isHidden = false
        errorLabel.isHidden = true
    }

    override func dismissPopupControllerAnimated() {
        if interceptDismiss {
            if payView.processing {
                return
            }
            if payView.pinField.isFirstResponder {
                payView.pinField.resignFirstResponder()
                return
            }
        }
        if showLoginView {
            loginView.onWindowWillDismiss()
        }
        super.dismissPopupControllerAnimated()
    }

    override func getAnimationStartPoint() -> CGPoint {
        return fromWeb ? animationPushOriginPoint : super.getAnimationStartPoint()
    }

    override func getAnimationEndPoint() -> CGPoint {
        return fromWeb ? animationPushEndPoint : super.getAnimationEndPoint()
    }

    class func instance() -> UrlWindow {
        return Bundle.main.loadNibNamed("UrlWindow", owner: nil, options: nil)?.first as! UrlWindow
    }
}

extension UrlWindow {

    class func checkCodesUrl(_ codeId: String, fromWeb: Bool = false, clearNavigationStack: Bool) -> Bool {
        guard !codeId.isEmpty, UUID(uuidString: codeId) != nil else {
            return false
        }

        UrlWindow.instance().presentPopupControllerAnimated(codeId: codeId, fromWeb: fromWeb, clearNavigationStack: clearNavigationStack)
        return true
    }

    class func checkUsersUrl(_ userId: String, fromWeb: Bool = false, clearNavigationStack: Bool) -> Bool {
        guard !userId.isEmpty, UUID(uuidString: userId) != nil else {
            return false
        }
        
        UrlWindow.instance().presentPopupControllerAnimated(userId: userId, fromWeb: fromWeb, clearNavigationStack: clearNavigationStack)
        return true
    }

    class func checkTransferUrl(_ userId: String, fromWeb: Bool = false, clearNavigationStack: Bool) -> Bool {
        guard !userId.isEmpty, UUID(uuidString: userId) != nil, userId != AccountAPI.shared.accountUserId else {
            return false
        }

        UrlWindow.instance().presentPopupControllerAnimated(userId: userId, fromWeb: fromWeb, clearNavigationStack: clearNavigationStack, transfer: true)
        return true
    }

    private func presentPopupControllerAnimated(codeId: String, fromWeb: Bool = false, clearNavigationStack: Bool) {
        self.fromWeb = fromWeb
        presentPopupControllerAnimated()

        UserAPI.shared.codes(codeId: codeId) { [weak self](result) in
            guard let weakSelf = self, weakSelf.isShowing else {
                return
            }

            switch result {
            case let .success(code):
                if let user = code.user {
                    UserDAO.shared.updateUsers(users: [user])
                    weakSelf.presentUser(user: UserItem.createUser(from: user), clearNavigationStack: clearNavigationStack, refreshUser: false)
                } else if let authorization = code.authorization {
                    weakSelf.load(authorization: authorization)
                } else if let conversation = code.conversation {
                    weakSelf.load(conversation: conversation, codeId: codeId)
                }
            case let .failure(error):
                if error.code == 404 {
                    weakSelf.failedHandler(Localized.CODE_RECOGNITION_FAIL_TITLE)
                } else {
                    weakSelf.failedHandler(error.localizedDescription)
                }
            }
        }
    }
    
    private func presentPopupControllerAnimated(userId: String, fromWeb: Bool = false, clearNavigationStack: Bool, transfer: Bool = false) {
        self.fromWeb = fromWeb
        presentPopupControllerAnimated()
        DispatchQueue.global().async { [weak self] in
            var asset: AssetItem?
            if transfer {
                asset = AssetDAO.shared.getAvailableAssetId(assetId: WalletUserDefault.shared.defalutTransferAssetId)
            }
            var user = UserDAO.shared.getUser(userId: userId)
            var refreshUser = true
            if user == nil {
                switch UserAPI.shared.showUser(userId: userId) {
                case let .success(response):
                    refreshUser = false
                    user = UserItem.createUser(from: response)
                    UserDAO.shared.updateUsers(users: [response])
                case let .failure(error):
                    DispatchQueue.main.async {
                        if error.code == 404 {
                            self?.failedHandler(Localized.CONTACT_SEARCH_NOT_FOUND)
                        } else {
                            self?.failedHandler(error.localizedDescription)
                        }
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                guard let weakSelf = self, weakSelf.isShowing, let user = user else {
                    return
                }
                if transfer {
                    weakSelf.dismissPopupControllerAnimated()
                    let conversationId = ConversationDAO.shared.makeConversationId(userId: userId, ownerUserId: AccountAPI.shared.accountUserId)
                    let vc = TransferViewController.instance(user: user, conversationId: conversationId, asset: asset)
                    if clearNavigationStack {
                        UIApplication.rootNavigationController()?.pushViewController(withBackRoot: vc)
                    } else {
                        UIApplication.rootNavigationController()?.pushViewController(vc, animated: true)
                    }
                } else {
                    weakSelf.presentUser(user: user, clearNavigationStack: clearNavigationStack, refreshUser: refreshUser)
                }
            }
        }
    }

    private func presentUser(user: UserItem, clearNavigationStack: Bool, refreshUser: Bool = true) {
        if user.userId == AccountAPI.shared.accountUserId {
            dismissPopupControllerAnimated()
            let vc = MyProfileViewController.instance()
            if clearNavigationStack {
                UIApplication.rootNavigationController()?.pushViewController(withBackRoot: vc)
            } else {
                UIApplication.rootNavigationController()?.pushViewController(vc, animated: true)
            }
        } else {
            containerView.addSubview(userView)
            userView.snp.makeConstraints({ (make) in
                make.edges.equalToSuperview()
            })
            userView.updateUser(user: user, refreshUser: refreshUser, superView: self)
            successHandler()
            contentHeightConstraint.constant = 0
            UIView.animate(withDuration: 0.15, animations: {
                self.layoutIfNeeded()
            })
        }
    }
    
    private func autoDismissWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let weakSelf = self, weakSelf.isShowing else {
                return
            }
            weakSelf.dismissPopupControllerAnimated()
        }
    }

    private func load(authorization: AuthorizationResponse) {
        DispatchQueue.global().async { [weak self] in
            let assets = AssetDAO.shared.getAvailableAssets()
            DispatchQueue.main.async {
                guard let weakSelf = self, weakSelf.isShowing else {
                    return
                }

                weakSelf.showLoginView = true
                weakSelf.containerView.addSubview(weakSelf.loginView)
                weakSelf.loginView.snp.makeConstraints({ (make) in
                    make.edges.equalToSuperview()
                })
                weakSelf.loginView.render(authInfo: authorization, assets: assets, superView: weakSelf)
                weakSelf.successHandler()

                UIView.animate(withDuration: 0.15, animations: {
                    weakSelf.layoutIfNeeded()
                })
            }
        }
    }

    private func load(conversation: ConversationResponse, codeId: String) {
        DispatchQueue.global().async { [weak self] in
            let subParticipants: ArraySlice<ParticipantResponse> = conversation.participants.prefix(4)
            let accountUserId = AccountAPI.shared.accountUserId
            let conversationId = conversation.conversationId
            let alreadyInTheGroup = conversation.participants.first(where: { $0.userId == accountUserId }) != nil
            let userIds = subParticipants.map{ $0.userId }
            var participants = [ParticipantUser]()
            switch UserAPI.shared.showUsers(userIds: userIds) {
            case let .success(users):
                participants = users.flatMap { ParticipantUser.createParticipantUser(conversationId: conversationId, user: $0) }
            case let .failure(error):
                DispatchQueue.main.async {
                    self?.failedHandler(error.localizedDescription)
                }
                return
            }
            var creatorUser = UserDAO.shared.getUser(userId: conversation.creatorId)
            if creatorUser == nil {
                switch UserAPI.shared.showUser(userId: conversation.creatorId) {
                case let .success(user):
                    creatorUser = UserItem.createUser(from: user)
                case let .failure(error):
                    DispatchQueue.main.async {
                        self?.failedHandler(error.localizedDescription)
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                guard let weakSelf = self, let ownerUser = creatorUser, weakSelf.isShowing else {
                    return
                }
                weakSelf.containerView.addSubview(weakSelf.groupView)
                weakSelf.groupView.snp.makeConstraints({ (make) in
                    make.edges.equalToSuperview()
                })
                weakSelf.groupView.render(codeId: codeId, conversation: conversation, ownerUser: ownerUser, participants: participants, alreadyInTheGroup: alreadyInTheGroup, superView: weakSelf)
                weakSelf.successHandler()

                weakSelf.contentHeightConstraint.constant = 0
                UIView.animate(withDuration: 0.15, animations: {
                    weakSelf.layoutIfNeeded()
                })
            }
        }
    }

    private func failedHandler(_ errorMsg: String) {
        loadingView.stopAnimating()
        loadingView.isHidden = true
        errorLabel.text = errorMsg
        errorLabel.isHidden = false
        autoDismissWindow()
    }

    private func successHandler() {
        loadingView.stopAnimating()
        loadingView.isHidden = true
        errorLabel.isHidden = true
    }
}

extension UrlWindow {

    func presentPopupControllerAnimated(assetId: String, opponentId: String, amount: String, traceId: String, memo: String, fromWeb: Bool = false) {
        self.fromWeb = fromWeb
        presentPopupControllerAnimated()
        AssetAPI.shared.payments(assetId: assetId, opponentId: opponentId, amount: amount, traceId: traceId) { [weak self](result) in
            guard let weakSelf = self, weakSelf.isShowing else {
                return
            }
            switch result {
            case let .success(payment):
                guard payment.status != PaymentStatus.paid.rawValue else {
                    weakSelf.failedHandler(Localized.TRANSFER_PAID)
                    return
                }
                if PayWindow.shared.isShowing {
                    PayWindow.shared.removeFromSuperview()
                }

                weakSelf.interceptDismiss = true

                weakSelf.containerView.addSubview(weakSelf.payView)
                weakSelf.payView.snp.makeConstraints({ (make) in
                    make.edges.equalToSuperview()
                })
                let chainIconUrl = AssetDAO.shared.getChainIconUrl(chainId: payment.asset.chainId)
                weakSelf.payView.render(asset: AssetItem.createAsset(asset: payment.asset, chainIconUrl: chainIconUrl), user: UserItem.createUser(from: payment.recipient), amount: amount, memo: memo, trackId: traceId, superView: weakSelf)
                weakSelf.successHandler()
            case let .failure(error):
                weakSelf.failedHandler(error.localizedDescription)
            }
        }
    }

    class func checkPayUrl(url: URL, fromWeb: Bool = false) -> Bool {
        guard let query = url.getKeyVals() else {
            return false
        }
        guard let recipientId = query["recipient"], let assetId = query["asset"], let amount = query["amount"], let traceId = query["trace"] else {
            return false
        }
        guard !recipientId.isEmpty && UUID(uuidString: recipientId) != nil && !assetId.isEmpty && UUID(uuidString: assetId) != nil && !traceId.isEmpty && UUID(uuidString: traceId) != nil && !amount.isEmpty else {
            return false
        }

        var memo = query["memo"]
        if let urlDecodeMemo = memo?.removingPercentEncoding {
            memo = urlDecodeMemo
        }
        UrlWindow.instance().presentPopupControllerAnimated(assetId: assetId, opponentId: recipientId, amount: amount, traceId: traceId, memo: memo ?? "", fromWeb: fromWeb)

        return true
    }

    class func checkSendUrl(url: URL, fromWeb: Bool = false) -> Bool {
        guard let query = url.getKeyVals() else {
            return false
        }
        guard let text = query["text"], !text.isEmpty else {
            return false
        }

        let shareText = text.removingPercentEncoding ?? text
        UIApplication.rootNavigationController()?.pushViewController(SendToViewController.instance(text: shareText), animated: true)

        return true
    }

}
