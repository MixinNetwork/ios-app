import Foundation
import UIKit
import Alamofire

class UrlWindow: BottomSheetView {

    @IBOutlet weak var loadingView: ActivityIndicatorView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var assistView: UIView!

    @IBOutlet weak var contentHeightConstraint: NSLayoutConstraint!

    private var animationPushOriginPoint: CGPoint {
        return CGPoint(x: self.bounds.size.width + self.popupView.bounds.size.width, y: self.popupView.center.y)
    }
    private var animationPushEndPoint: CGPoint {
        return CGPoint(x: self.bounds.size.width-(self.popupView.bounds.size.width * 0.5), y: self.popupView.center.y)
    }

    private lazy var payView = PayView.instance()

    private(set) var fromWeb = false
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
            return checkCodesUrl(code, clearNavigationStack: clearNavigationStack)
        case .pay:
            return checkPayUrl(url: url, fromWeb: fromWeb)
        case .withdrawal:
            return checkWithdrawal(url: url, fromWeb: fromWeb)
        case .address:
            return checkAddress(url: url)
        case let .users(id):
            return checkUsersUrl(id, clearNavigationStack: clearNavigationStack)
        case let .transfer(id):
            return checkTransferUrl(id, clearNavigationStack: clearNavigationStack)
        case .send:
            return checkSendUrl(url: url, fromWeb: fromWeb)
        case .device:
            return false
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

    class func checkUsersUrl(_ userId: String, clearNavigationStack: Bool) -> Bool {
        guard !userId.isEmpty, UUID(uuidString: userId) != nil else {
            return false
        }

        DispatchQueue.global().async {
            var userItem = UserDAO.shared.getUser(userId: userId)
            var refreshUser = true
            if userItem == nil {
                switch UserAPI.shared.showUser(userId: userId) {
                case let .success(response):
                    refreshUser = false
                    userItem = UserItem.createUser(from: response)
                    UserDAO.shared.updateUsers(users: [response])
                case let .failure(error):
                    DispatchQueue.main.async {
                        if error.code == 404 {
                            showAutoHiddenHud(style: .error, text: Localized.CONTACT_SEARCH_NOT_FOUND)
                        } else {
                            showAutoHiddenHud(style: .error, text: error.localizedDescription)
                        }
                    }
                    return
                }
            }

            guard let user = userItem, user.isCreatedByMessenger else {
                return
            }

            DispatchQueue.main.async {
                UserWindow.instance().updateUser(user: user, refreshUser: refreshUser).presentPopupControllerAnimated()
            }
        }
        return true
    }

    class func checkTransferUrl(_ userId: String, clearNavigationStack: Bool) -> Bool {
        guard !userId.isEmpty, UUID(uuidString: userId) != nil, userId != AccountAPI.shared.accountUserId else {
            return false
        }

        DispatchQueue.global().async {
            var userItem = UserDAO.shared.getUser(userId: userId)
            if userItem == nil {
                switch UserAPI.shared.showUser(userId: userId) {
                case let .success(response):
                    userItem = UserItem.createUser(from: response)
                    UserDAO.shared.updateUsers(users: [response])
                case let .failure(error):
                    DispatchQueue.main.async {
                        if error.code == 404 {
                            showAutoHiddenHud(style: .error, text: Localized.CONTACT_SEARCH_NOT_FOUND)
                        } else {
                            showAutoHiddenHud(style: .error, text: error.localizedDescription)
                        }
                    }
                    return
                }
            }

            guard let user = userItem, user.isCreatedByMessenger else {
                return
            }

            DispatchQueue.main.async {
                let vc = TransferOutViewController.instance(asset: nil, type: .contact(user))
                if clearNavigationStack {
                    UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
                } else {
                    UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
                }
            }
        }
        return true
    }

    private func presentPopupControllerAnimated(codeId: String, fromWeb: Bool = false, clearNavigationStack: Bool) {
        self.fromWeb = fromWeb
        presentPopupControllerAnimated()
    }

    private func failedHandler(_ errorMsg: String) {
        loadingView.stopAnimating()
        errorLabel.text = errorMsg
        errorLabel.isHidden = false
    }

    private func successHandler() {
        loadingView.stopAnimating()
        errorLabel.isHidden = true
    }
}

extension UrlWindow {

    func presentPopupControllerAnimated(addressId: String, assetId: String, amount: String, traceId: String, memo: String, fromWeb: Bool = false) {
        self.fromWeb = fromWeb
        presentPopupControllerAnimated()

        DispatchQueue.global().async { [weak self] in
            guard let asset = AssetDAO.shared.getAsset(assetId: assetId) else {
                DispatchQueue.main.async {
                    self?.failedHandler(R.string.localizable.address_asset_not_found())
                }
                return
            }
            var address = AddressDAO.shared.getAddress(addressId: addressId)
            if address == nil {
                switch WithdrawalAPI.shared.address(addressId: addressId) {
                case let .success(remoteAddress):
                    AddressDAO.shared.insertOrUpdateAddress(addresses: [remoteAddress])
                    address = remoteAddress
                case let .failure(error):
                    DispatchQueue.main.async {
                        if error.code == 404 {
                            self?.failedHandler(R.string.localizable.address_not_found())
                        } else {
                            self?.failedHandler(error.localizedDescription)
                        }
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                guard let weakSelf = self, weakSelf.isShowing else {
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
                if let address = address {
                    weakSelf.payView.render(asset: asset, address: address, amount: amount, memo: memo, trackId: traceId, fromWebWithdrawal: true, superView: weakSelf)
                }
                weakSelf.successHandler()
            }
        }
    }

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
                let chainAsset = AssetDAO.shared.getAsset(assetId: payment.asset.chainId)
                weakSelf.payView.render(asset: AssetItem.createAsset(asset: payment.asset, chainIconUrl: chainAsset?.iconUrl, chainName: chainAsset?.name), user: UserItem.createUser(from: payment.recipient), amount: amount, memo: memo, trackId: traceId, superView: weakSelf)
                weakSelf.successHandler()
            case let .failure(error):
                weakSelf.failedHandler(error.localizedDescription)
            }
        }
    }

    class func checkPayUrl(url: URL, fromWeb: Bool = false) -> Bool {
        guard AccountAPI.shared.account?.has_pin ?? false else {
            UIApplication.homeNavigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil), animated: true)
            return true
        }
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

    class func checkAddress(url: URL) -> Bool {
        guard AccountAPI.shared.account?.has_pin ?? false else {
            UIApplication.homeNavigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil), animated: true)
            return true
        }
        guard let query = url.getKeyVals() else {
            return false
        }
        guard let assetId = query["asset"], !assetId.isEmpty, UUID(uuidString: assetId) != nil else {
            return false
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.window)
        DispatchQueue.global().async {
            guard var asset = AssetDAO.shared.getAsset(assetId: assetId) else {
                DispatchQueue.main.async {
                    hud.set(style: .error, text: R.string.localizable.address_asset_not_found())
                    hud.scheduleAutoHidden()
                }
                return
            }

            while asset.destination.isEmpty {
                switch AssetAPI.shared.asset(assetId: asset.assetId) {
                case let .success(remoteAsset):
                    guard !remoteAsset.destination.isEmpty else {
                        Thread.sleep(forTimeInterval: 2)
                        continue
                    }
                    guard let localAsset = AssetDAO.shared.saveAsset(asset: remoteAsset) else {
                        return
                    }
                    asset = localAsset
                    break
                case let .failure(error):
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                    return
                }
            }

            var addressRequest: AddressRequest?
            var address: Address?

            let addressAction: AddressView.action
            if let action = query["action"]?.lowercased(), "delete" == action {
                guard let addressId = query["address"], !addressId.isEmpty && UUID(uuidString: addressId) != nil else {
                    return
                }

                addressAction = .delete
                address = AddressDAO.shared.getAddress(addressId: addressId)
                if address == nil {
                    switch WithdrawalAPI.shared.address(addressId: addressId) {
                    case let .success(remoteAddress):
                        AddressDAO.shared.insertOrUpdateAddress(addresses: [remoteAddress])
                        address = remoteAddress
                    case let .failure(error):
                        DispatchQueue.main.async {
                            if error.code == 404 {
                                hud.set(style: .error, text: R.string.localizable.address_not_found())
                            } else {
                                hud.set(style: .error, text: error.localizedDescription)
                            }
                            hud.scheduleAutoHidden()
                        }
                        return
                    }
                }
            } else {
                guard let label = query["label"], let destination = query["destination"], !label.isEmpty, !destination.isEmpty else {
                    return
                }

                let tag = query["tag"] ?? ""

                addressRequest = AddressRequest(assetId: assetId, destination: destination, tag: tag, label: label, pin: "")
                address = AddressDAO.shared.getAddress(assetId: assetId, destination: destination, tag: tag)
                addressAction = address == nil ? .add : .update
            }

            DispatchQueue.main.async {
                hud.hide()
                AddressWindow.instance().presentPopupControllerAnimated(action: addressAction, asset: asset, addressRequest: addressRequest, address: address, dismissCallback: nil)
            }
        }
        return true
    }

    class func checkWithdrawal(url: URL, fromWeb: Bool = false) -> Bool {
        guard AccountAPI.shared.account?.has_pin ?? false else {
            UIApplication.homeNavigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil), animated: true)
            return true
        }
        guard let query = url.getKeyVals() else {
            return false
        }
        guard let assetId = query["asset"], let amount = query["amount"], let traceId = query["trace"], let addressId = query["address"] else {
            return false
        }
        guard !assetId.isEmpty && UUID(uuidString: assetId) != nil && !traceId.isEmpty && UUID(uuidString: traceId) != nil && !addressId.isEmpty && UUID(uuidString: addressId) != nil && !amount.isEmpty else {
            return false
        }
        var memo = query["memo"]
        if let urlDecodeMemo = memo?.removingPercentEncoding {
            memo = urlDecodeMemo
        }

        UrlWindow.instance().presentPopupControllerAnimated(addressId: addressId, assetId: assetId, amount: amount, traceId: traceId, memo: memo ?? "", fromWeb: fromWeb)

        return true
    }

    class func checkSendUrl(url: URL, fromWeb: Bool = false) -> Bool {
        guard let query = url.getKeyVals() else {
            return false
        }
        guard let text = query["text"], !text.isEmpty else {
            return false
        }
        
        let vc = MessageReceiverViewController.instance(content: .text(text))
        UIApplication.homeNavigationController?.pushViewController(vc, animated: true)

        return true
    }

}

extension UrlWindow {

    private static func checkCodesUrl(_ codeId: String, clearNavigationStack: Bool) -> Bool {
        guard !codeId.isEmpty, UUID(uuidString: codeId) != nil else {
            return false
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.window)

        UserAPI.shared.codes(codeId: codeId) { (result) in
            switch result {
            case let .success(code):
                hud.hide()
                if let user = code.user {
                    presentUser(user: user, hud: hud)
                } else if let authorization = code.authorization {
                    presentAuthorization(authorization: authorization, hud: hud)
                } else if let conversation = code.conversation {
                    presentConversation(conversation: conversation, codeId: codeId, hud: hud)
                }
            case let .failure(error):
                if error.code == 404 {
                    hud.set(style: .error, text: Localized.CODE_RECOGNITION_FAIL_TITLE)
                } else {
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
            }
        }
        return true
    }

    private static func presentUser(user: UserResponse, hud: Hud) {
        DispatchQueue.global().async {
            UserDAO.shared.updateUsers(users: [user])

            DispatchQueue.main.async {
                hud.hide()
                UserWindow.instance().updateUser(user: UserItem.createUser(from: user), refreshUser: false).presentPopupControllerAnimated()
            }
        }
    }

    private static func presentAuthorization(authorization: AuthorizationResponse, hud: Hud) {
        DispatchQueue.global().async {
            let assets = AssetDAO.shared.getAvailableAssets()

            DispatchQueue.main.async {
                hud.hide()
                AuthorizationWindow.instance().render(authInfo: authorization, assets: assets).presentPopupControllerAnimated()
            }
        }
    }

    private static func presentConversation(conversation: ConversationResponse, codeId: String, hud: Hud) {
        DispatchQueue.global().async {
            defer {
                DispatchQueue.main.async {
                    hud.hide()
                }
            }
            let subParticipants: ArraySlice<ParticipantResponse> = conversation.participants.prefix(4)
            let accountUserId = AccountAPI.shared.accountUserId
            let conversationId = conversation.conversationId
            let alreadyInTheGroup = conversation.participants.first(where: { $0.userId == accountUserId }) != nil
            let userIds = subParticipants.map{ $0.userId }
            var participants = [ParticipantUser]()
            switch UserAPI.shared.showUsers(userIds: userIds) {
            case let .success(users):
                participants = users.map {
                    ParticipantUser.createParticipantUser(conversationId: conversationId, user: $0)
                }
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
                return
            }
            var creatorUser = UserDAO.shared.getUser(userId: conversation.creatorId)
            if creatorUser == nil {
                switch UserAPI.shared.showUser(userId: conversation.creatorId) {
                case let .success(user):
                    creatorUser = UserItem.createUser(from: user)
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                    return
                }
            }

            guard let ownerUser = creatorUser else {
                return
            }

            DispatchQueue.main.async {
                GroupWindow.instance().updateGroup(codeId: codeId, conversation: conversation, ownerUser: ownerUser, participants: participants, alreadyInTheGroup: alreadyInTheGroup).presentPopupControllerAnimated()
            }
        }
    }
}
