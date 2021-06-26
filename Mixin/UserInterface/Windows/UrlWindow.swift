import Foundation
import UIKit
import Alamofire
import MixinServices

class UrlWindow {
    
    class func checkUrl(url: URL, webContext: MixinWebViewController.Context? = nil, clearNavigationStack: Bool = true, ignoreUnsupportMixinSchema: Bool = true) -> Bool {
        if let mixinURL = MixinURL(url: url) {
            switch mixinURL {
            case let .codes(code):
                return checkCodesUrl(code, clearNavigationStack: clearNavigationStack, webContext: webContext)
            case .pay:
                return checkPayUrl(url: url.absoluteString, query: url.getKeyVals())
            case .withdrawal:
                return checkWithdrawal(url: url)
            case .address:
                return checkAddress(url: url)
            case let .users(id):
                return checkUser(id, clearNavigationStack: clearNavigationStack)
            case .snapshots:
                return checkSnapshot(url: url)
            case let .conversations(conversationId, userId):
                return checkConversation(conversationId: conversationId, userId: userId)
            case let .apps(userId):
                return checkApp(url: url, userId: userId)
            case let .transfer(id):
                return checkTransferUrl(id, clearNavigationStack: clearNavigationStack)
            case let .send(context):
                return checkSendUrl(sharingContext: context, webContext: webContext)
            case let .device(id, publicKey):
                LoginConfirmWindow.instance(id: id, publicKey: publicKey).presentView()
                return true
            case .upgradeDesktop:
                UIApplication.currentActivity()?.alert(R.string.localizable.desktop_upgrade())
                return true
            case .unknown:
                return ignoreUnsupportMixinSchema ? url.scheme == MixinURL.scheme : false
            }
        } else if let url = MixinInternalURL(url: url) {
            switch url {
            case let .identityNumber(number):
                return checkUser(identityNumber: number)
            }
        } else {
            return false
        }
    }

    class func checkApp(url: URL, userId: String) -> Bool {
        guard !userId.isEmpty, UUID(uuidString: userId) != nil else {
            return false
        }

        let params = url.getKeyVals()
        let isOpenApp = params["action"] == "open"

        DispatchQueue.global().async {
            var appItem = AppDAO.shared.getApp(ofUserId: userId)
            var userItem = UserDAO.shared.getUser(userId: userId)
            var refreshUser = true
            if appItem == nil || userItem == nil {
                switch UserAPI.showUser(userId: userId) {
                case let .success(response):
                    refreshUser = false
                    userItem = UserItem.createUser(from: response)
                    appItem = response.app
                    UserDAO.shared.updateUsers(users: [response])
                case let .failure(error):
                    let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.app_not_found())
                    DispatchQueue.main.async {
                        showAutoHiddenHud(style: .error, text: text)
                    }
                    return
                }
            }

            guard let user = userItem else {
                return
            }

            guard let app = appItem else {
                DispatchQueue.main.async {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.app_not_found())
                }
                return
            }

            let conversationId = ConversationDAO.shared.makeConversationId(userId: user.userId, ownerUserId: myUserId)

            DispatchQueue.main.async {
                if isOpenApp {
                    guard let parent = UIApplication.homeNavigationController?.visibleViewController else {
                        return
                    }
                    let userInfo = ["source": "UrlWindow", "identityNumber": app.appNumber]
                    reporter.report(event: .openApp, userInfo: userInfo)
                    let extraParams = params.filter { $0.key != "action" }
                    DispatchQueue.main.async {
                        MixinWebViewController.presentInstance(with: .init(conversationId: conversationId, app: app, extraParams: extraParams), asChildOf: parent)
                    }
                } else {
                    let vc = UserProfileViewController(user: user)
                    vc.updateUserFromRemoteAfterReloaded = refreshUser
                    UIApplication.homeContainerViewController?.present(vc, animated: true, completion: nil)
                }
            }
        }
        return true
    }

    class func checkSnapshot(url: URL) -> Bool {
        let snapshotId: String? = (url.pathComponents.count > 1 ? url.pathComponents[1] : nil).uuidString
        let traceId: String? = url.getKeyVals()["trace"].uuidString

        guard !snapshotId.isNilOrEmpty || !traceId.isNilOrEmpty else {
            return false
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            var snapshotItem: SnapshotItem?
            if let traceId = traceId  {
                snapshotItem = SnapshotDAO.shared.getSnapshot(traceId: traceId)
                if snapshotItem == nil {
                    switch SnapshotAPI.trace(traceId: traceId) {
                    case let .success(snapshot):
                        snapshotItem = SnapshotDAO.shared.saveSnapshot(snapshot: snapshot)
                    case let .failure(error):
                        let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.snapshot_not_found())
                        DispatchQueue.main.async {
                            hud.set(style: .error, text: text)
                            hud.scheduleAutoHidden()
                        }
                        return
                    }
                }
            } else if let snapshotId = snapshotId {
                snapshotItem = SnapshotDAO.shared.getSnapshot(snapshotId: snapshotId)
                if snapshotItem == nil {
                    switch SnapshotAPI.snapshot(snapshotId: snapshotId) {
                    case let .success(snapshot):
                        snapshotItem = SnapshotDAO.shared.saveSnapshot(snapshot: snapshot)
                    case let .failure(error):
                        let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.snapshot_not_found())
                        DispatchQueue.main.async {
                            hud.set(style: .error, text: text)
                            hud.scheduleAutoHidden()
                        }
                        return
                    }
                }
            }

            guard let snapshot = snapshotItem, let assetItem = syncAsset(assetId: snapshot.assetId, hud: hud) else {
                return
            }

            if snapshot.type == SnapshotType.transfer.rawValue, let opponentId = snapshot.opponentId {
                if !UserDAO.shared.isExist(userId: opponentId) {
                    if case let .success(response) = UserAPI.showUser(userId: opponentId) {
                        UserDAO.shared.updateUsers(users: [response])
                    }
                }
            }
            
            DispatchQueue.main.async {
                func push() {
                    hud.hide()
                    let vc = TransactionViewController.instance(asset: assetItem, snapshot: snapshot)
                    UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
                }
                
                if UIApplication.homeContainerViewController?.isShowingGallery ?? false {
                    UIApplication.homeContainerViewController?.galleryViewController.dismiss(transitionViewInitialOffsetY: 0) {
                        push()
                    }
                } else {
                    push()
                }
            }
        }
        return true
    }
    
    class func checkConversation(conversationId: String, userId: String?) -> Bool {
        guard !conversationId.isEmpty, UUID(uuidString: conversationId) != nil else {
            return false
        }
        
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            if let userId = userId, conversationId == ConversationDAO.shared.makeConversationId(userId: userId, ownerUserId: myUserId) {
                guard let (user, _) = syncUser(userId: userId, hud: hud) else {
                    return
                }
                guard user.isCreatedByMessenger else {
                    hud.hideInMainThread()
                    return
                }
                DispatchQueue.main.async {
                    hud.hide()
                    let vc = ConversationViewController.instance(ownerUser: user)
                    UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
                }
            } else {
                var conversation = ConversationDAO.shared.getConversation(conversationId: conversationId)
                var isMember = false
                if conversation == nil {
                    switch ConversationAPI.getConversation(conversationId: conversationId) {
                    case let .success(response):
                        guard response.participants.contains(where: { $0.userId == myUserId }) else {
                            DispatchQueue.main.async {
                                hud.set(style: .error, text: R.string.localizable.conversation_not_found())
                                hud.scheduleAutoHidden()
                            }
                            return
                        }
                        isMember = true
                        conversation = ConversationDAO.shared.createConversation(conversation: response, targetStatus: .SUCCESS)
                    case let .failure(error):
                        let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.conversation_not_found())
                        DispatchQueue.main.async {
                            hud.set(style: .error, text: text)
                            hud.scheduleAutoHidden()
                        }
                        return
                    }
                } else {
                    isMember = ParticipantDAO.shared.userId(myUserId, isParticipantOfConversationId: conversationId)
                }
                
                guard let conversation = conversation, isMember else {
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: R.string.localizable.conversation_not_found())
                        hud.scheduleAutoHidden()
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    hud.hide()
                    let vc = ConversationViewController.instance(conversation: conversation)
                    UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
                }
            }
        }
        return true
    }

    class func checkUser(_ userId: String, clearNavigationStack: Bool) -> Bool {
        guard !userId.isEmpty, UUID(uuidString: userId) != nil else {
            return false
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            guard let (user, updateUserFromRemoteAfterReloaded) = syncUser(userId: userId, hud: hud) else {
                return
            }
            guard user.isCreatedByMessenger else {
                hud.hideInMainThread()
                return
            }

            DispatchQueue.main.async {
                hud.hide()
                let vc = UserProfileViewController(user: user)
                vc.updateUserFromRemoteAfterReloaded = updateUserFromRemoteAfterReloaded
                UIApplication.homeContainerViewController?.present(vc, animated: true, completion: nil)
            }
        }
        return true
    }
    
    class func checkUser(identityNumber: String) -> Bool {
        guard !identityNumber.isEmpty else {
            return false
        }
        DispatchQueue.global().async {
            var userItem = UserDAO.shared.getUser(identityNumber: identityNumber)
            var updateUserFromRemoteAfterReloaded = true
            if userItem == nil {
                switch UserAPI.search(keyword: identityNumber) {
                case let .success(response):
                    updateUserFromRemoteAfterReloaded = false
                    userItem = UserItem.createUser(from: response)
                    UserDAO.shared.updateUsers(users: [response])
                case let .failure(error):
                    let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.user_not_found())
                    DispatchQueue.main.async {
                        showAutoHiddenHud(style: .error, text: text)
                    }
                    return
                }
            }
            guard let user = userItem, user.isCreatedByMessenger else {
                return
            }
            DispatchQueue.main.async {
                let vc = UserProfileViewController(user: user)
                vc.updateUserFromRemoteAfterReloaded = updateUserFromRemoteAfterReloaded
                UIApplication.homeContainerViewController?.present(vc, animated: true, completion: nil)
            }
        }
        return true
    }
    
    class func checkTransferUrl(_ userId: String, clearNavigationStack: Bool) -> Bool {
        guard !userId.isEmpty, UUID(uuidString: userId) != nil, userId != myUserId else {
            return false
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            guard let (user, _) = syncUser(userId: userId, hud: hud) else {
                return
            }

            DispatchQueue.main.async {
                hud.hide()
                func push() {
                    let vc = TransferOutViewController.instance(asset: nil, type: .contact(user))
                    if clearNavigationStack {
                        UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
                    } else {
                        UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
                    }
                }
                if UIApplication.homeContainerViewController?.isShowingGallery ?? false {
                    UIApplication.homeContainerViewController?.galleryViewController.dismiss(transitionViewInitialOffsetY: 0) {
                        push()
                    }
                } else {
                    push()
                }
            }
        }
        return true
    }

    class func checkWithdrawal(url: URL) -> Bool {
        guard LoginManager.shared.account?.has_pin ?? false else {
            UIApplication.homeNavigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil), animated: true)
            return true
        }
        let query = url.getKeyVals()
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

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            guard let asset = syncAsset(assetId: assetId, hud: hud) else {
                return
            }
            guard let chainAsset = syncAsset(assetId: asset.chainId, hud: hud) else {
                return
            }
            guard let address = syncAddress(addressId: addressId, hud: hud) else {
                return
            }

            let action: PayWindow.PinAction = .withdraw(trackId: traceId, address: address, chainAsset: chainAsset, fromWeb: true)
            PayWindow.checkPay(traceId: traceId, asset: asset, action: action, destination: address.destination, tag: address.tag, addressId: address.addressId, amount: amount, memo: memo ?? "", fromWeb: true) { (canPay, errorMsg) in

                DispatchQueue.main.async {
                    if canPay {
                        hud.hide()
                        PayWindow.instance().render(asset: asset, action: action, amount: amount, memo: memo ?? "").presentPopupControllerAnimated()
                    } else if let error = errorMsg {
                        hud.set(style: .error, text: error)
                        hud.scheduleAutoHidden()
                    } else {
                        hud.hide()
                    }
                }
            }
        }

        return true
    }

    class func checkPayUrl(url: String) -> Bool {
        guard ["bitcoin:", "bitcoincash:", "bitcoinsv:", "ethereum:", "litecoin:", "dash:", "ripple:", "zcash:", "horizen:", "monero:", "binancecoin:", "stellar:", "dogecoin:", "mobilecoin:"].contains(where: url.lowercased().hasPrefix) else {
            return false
        }
        guard let components = URLComponents(string: url.lowercased()) else {
            return false
        }
        return checkPayUrl(url: url, query: components.getKeyVals())
    }

    class func checkPayUrl(url: String, query: [String: String]) -> Bool {
        guard LoginManager.shared.account?.has_pin ?? false else {
            UIApplication.homeNavigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil), animated: true)
            return true
        }
        guard let recipientId = query["recipient"], let assetId = query["asset"], let amount = query["amount"] else {
            Logger.write(errorMsg: "[UrlWindow][CheckPayUrl]\(url)")
            showAutoHiddenHud(style: .error, text: R.string.localizable.url_invalid_payment())
            return true
        }
        guard !recipientId.isEmpty && UUID(uuidString: recipientId) != nil && !assetId.isEmpty && UUID(uuidString: assetId) != nil && !amount.isEmpty && amount.isGenericNumber else {
            Logger.write(errorMsg: "[UrlWindow][CheckPayUrl]\(url)")
            showAutoHiddenHud(style: .error, text: R.string.localizable.url_invalid_payment())
            return true
        }

        let traceId = query["trace"].uuidString ?? UUID().uuidString.lowercased()
        var memo = query["memo"]
        if let urlDecodeMemo = memo?.removingPercentEncoding {
            memo = urlDecodeMemo
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            guard let asset = syncAsset(assetId: assetId, hud: hud) else {
                return
            }
            guard let (user, _) = syncUser(userId: recipientId, hud: hud) else {
                return
            }

            let action: PayWindow.PinAction = .transfer(trackId: traceId, user: user, fromWeb: true)
            PayWindow.checkPay(traceId: traceId, asset: asset, action: action, opponentId: recipientId, amount: amount, memo: memo ?? "", fromWeb: true) { (canPay, errorMsg) in
                DispatchQueue.main.async {
                    if canPay {
                        hud.hide()
                        PayWindow.instance().render(asset: asset, action: action, amount: amount, memo: memo ?? "").presentPopupControllerAnimated()
                    } else if let error = errorMsg {
                        hud.set(style: .error, text: error)
                        hud.scheduleAutoHidden()
                    } else {
                        hud.hide()
                    }
                }
            }
        }
        return true
    }

    class func checkAddress(url: URL) -> Bool {
        guard LoginManager.shared.account?.has_pin ?? false else {
            UIApplication.homeNavigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil), animated: true)
            return true
        }
        let query = url.getKeyVals()
        guard let assetId = query["asset"], !assetId.isEmpty, UUID(uuidString: assetId) != nil else {
            return false
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            guard var asset = syncAsset(assetId: assetId, hud: hud) else {
                return
            }

            while asset.destination.isEmpty {
                switch AssetAPI.asset(assetId: asset.assetId) {
                case let .success(remoteAsset):
                    guard !remoteAsset.destination.isEmpty else {
                        Thread.sleep(forTimeInterval: 2)
                        continue
                    }
                    guard let localAsset = AssetDAO.shared.saveAsset(asset: remoteAsset) else {
                        hud.hideInMainThread()
                        return
                    }
                    asset = localAsset
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
                    hud.hideInMainThread()
                    return
                }

                addressAction = .delete
                address = AddressDAO.shared.getAddress(addressId: addressId)
                if address == nil {
                    switch WithdrawalAPI.address(addressId: addressId) {
                    case let .success(remoteAddress):
                        AddressDAO.shared.insertOrUpdateAddress(addresses: [remoteAddress])
                        address = remoteAddress
                    case let .failure(error):
                        let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.address_not_found())
                        DispatchQueue.main.async {
                            hud.set(style: .error, text: text)
                            hud.scheduleAutoHidden()
                        }
                        return
                    }
                }
            } else {
                guard let label = query["label"], let destination = query["destination"], !label.isEmpty, !destination.isEmpty else {
                    hud.hideInMainThread()
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
    
    class func checkSendUrl(sharingContext: ExternalSharingContext, webContext: MixinWebViewController.Context?) -> Bool {
        var sharingContext = sharingContext
        var message = Message.createMessage(context: sharingContext)
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        
        func presentSendingConfirmation() {
            guard let conversationId = sharingContext.conversationId, !conversationId.isEmpty, sharingContext.conversationId == UIApplication.currentConversationId() else {
                hud.hideInMainThread()
                let vc = MessageReceiverViewController.instance(content: .message(message))
                UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
                return
            }
            
            DispatchQueue.global().async {
                guard let conversation = ConversationDAO.shared.getConversation(conversationId: message.conversationId) else {
                    hud.hideInMainThread()
                    return
                }
                guard let (ownerUser, _) = syncUser(userId: conversation.ownerId, hud: hud) else {
                    return
                }
                
                DispatchQueue.main.async {
                    hud.hide()
                    let vc = R.storyboard.chat.external_sharing_confirmation()!
                    vc.modalPresentationStyle = .custom
                    vc.transitioningDelegate = PopupPresentationManager.shared
                    UIApplication.homeContainerViewController?.present(vc, animated: true, completion: nil)
                    vc.load(sharingContext: sharingContext, message: message, conversation: conversation, ownerUser: ownerUser, webContext: webContext)
                }
            }
        }
        
        switch sharingContext.content {
        case .contact(let data):
            DispatchQueue.global().async {
                guard let (_, _) = syncUser(userId: data.userId, hud: hud) else {
                    return
                }
                DispatchQueue.main.async {
                    presentSendingConfirmation()
                }
            }
        case .image(let imageURL):
            AF.request(imageURL).responseData { (response) in
                guard case let .success(data) = response.result, let image = UIImage(data: data) else {
                    hud.hideInMainThread()
                    return
                }
                let mimeType = response.response?.mimeType ?? "image/jpeg"
                let pathExt = (FileManager.default.pathExtension(mimeType: mimeType) ?? "jpg").lowercased()
                let fileUrl = AttachmentContainer.url(for: .photos, filename: message.messageId + "." + pathExt)
                
                DispatchQueue.global().async {
                    do {
                        try data.write(to: fileUrl)
                    } catch {
                        hud.hideInMainThread()
                        return
                    }
                    message.thumbImage = image.base64Thumbnail()
                    message.mediaMimeType = mimeType
                    message.mediaWidth = Int(image.size.width)
                    message.mediaHeight = Int(image.size.height)
                    message.mediaSize = FileManager.default.fileSize(fileUrl.path)
                    message.mediaUrl = fileUrl.lastPathComponent
                    
                    sharingContext.content = .image(fileUrl)
                    
                    DispatchQueue.main.async {
                        presentSendingConfirmation()
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                presentSendingConfirmation()
            }
        }
        return true
    }
    
}

extension UrlWindow {

    private static func checkCodesUrl(_ codeId: String, clearNavigationStack: Bool, webContext: MixinWebViewController.Context? = nil) -> Bool {
        guard !codeId.isEmpty, UUID(uuidString: codeId) != nil else {
            return false
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)

        UserAPI.codes(codeId: codeId) { (result) in
            switch result {
            case let .success(code):
                if let user = code.user {
                    presentUser(user: user, hud: hud)
                } else if let authorization = code.authorization {
                    presentAuthorization(authorization: authorization, webContext: webContext, hud: hud)
                } else if let conversation = code.conversation {
                    presentConversation(conversation: conversation, codeId: codeId, hud: hud)
                } else if let multisig = code.multisig {
                    presentMultisig(multisig: multisig, hud: hud)
                } else if let payment = code.payment {
                    presentPayment(payment: payment, hud: hud)
                } else {
                    hud.hide()
                }
            case let .failure(error):
                let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.code_recognition_fail_title())
                hud.set(style: .error, text: text)
                hud.scheduleAutoHidden()
            }
        }
        return true
    }

    private static func syncAddress(addressId: String, hud: Hud) -> Address? {
        var address = AddressDAO.shared.getAddress(addressId: addressId)
        if address == nil {
            switch WithdrawalAPI.address(addressId: addressId) {
            case let .success(remoteAddress):
                AddressDAO.shared.insertOrUpdateAddress(addresses: [remoteAddress])
                address = remoteAddress
            case let .failure(error):
                DispatchQueue.main.async {
                    let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.address_not_found())
                    hud.set(style: .error, text: text)
                    hud.scheduleAutoHidden()
                }
                return nil
            }
        }

        if address == nil {
            DispatchQueue.main.async {
                hud.set(style: .error, text: R.string.localizable.address_not_found())
                hud.scheduleAutoHidden()
            }
        }

        return address
    }
    
    private static func syncAsset(assetId: String, hud: Hud) -> AssetItem? {
        var asset = AssetDAO.shared.getAsset(assetId: assetId)
        if asset == nil {
            switch AssetAPI.asset(assetId: assetId) {
            case let .success(assetItem):
                asset = AssetDAO.shared.saveAsset(asset: assetItem)
            case let .failure(error):
                let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.asset_not_found())
                DispatchQueue.main.async {
                    hud.set(style: .error, text: text)
                    hud.scheduleAutoHidden()
                }
                return nil
            }
        }

        if asset == nil {
            DispatchQueue.main.async {
                hud.set(style: .error, text: R.string.localizable.asset_not_found())
                hud.scheduleAutoHidden()
            }
        }

        return asset
    }

    private static func syncUser(userId: String, hud: Hud) -> (UserItem, Bool)? {
        var user = UserDAO.shared.getUser(userId: userId)
        var loadUserFromLocal = true
        if user == nil {
            switch UserAPI.showUser(userId: userId) {
            case let .success(userItem):
                loadUserFromLocal = false
                user = UserItem.createUser(from: userItem)
                UserDAO.shared.updateUsers(users: [userItem])
            case let .failure(error):
                let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.user_not_found())
                DispatchQueue.main.async {
                    hud.set(style: .error, text: text)
                    hud.scheduleAutoHidden()
                }
                return nil
            }
        }

        if let userItem = user {
            return (userItem, loadUserFromLocal)
        } else {
            DispatchQueue.main.async {
                hud.set(style: .error, text: R.string.localizable.user_not_found())
                hud.scheduleAutoHidden()
            }
            return nil
        }
    }
    
    private static func syncUsers(userIds: [String], hud: Hud) -> [UserItem]? {
        let uniqueUserIds = userIds.filterDuplicates()
        var users = UserDAO.shared.getUsers(with: uniqueUserIds)
        let syncUserIds = uniqueUserIds.symmetricDifference(from: users.compactMap { $0.userId })
        
        if !syncUserIds.isEmpty {
            switch UserAPI.showUsers(userIds: syncUserIds) {
            case let .success(userItems):
                UserDAO.shared.updateUsers(users: userItems)
                users += userItems.compactMap { UserItem.createUser(from: $0) }
            case let .failure(error):
                DispatchQueue.main.async {
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
                return nil
            }
        }
        
        return users
    }

    private static func presentMultisig(multisig: MultisigResponse, hud: Hud) {
        guard LoginManager.shared.account?.has_pin ?? false else {
            UIApplication.homeNavigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil), animated: true)
            DispatchQueue.main.async {
                hud.hide()
            }
            return
        }
        DispatchQueue.global().async {
            guard let asset = syncAsset(assetId: multisig.assetId, hud: hud) else {
                return
            }
            guard let users = syncUsers(userIds: multisig.senders + multisig.receivers, hud: hud) else {
                return
            }

            let senderUsers = users.filter { multisig.senders.contains($0.userId) }
            let receiverUsers = users.filter { multisig.receivers.contains($0.userId) }

            var error = ""
            if multisig.action == MultisigAction.sign.rawValue && multisig.state == MultisigState.signed.rawValue {
                error = R.string.localizable.multisig_state_signed()
            } else if multisig.action == MultisigAction.unlock.rawValue && multisig.state == MultisigState.unlocked.rawValue {
                error = R.string.localizable.multisig_state_unlocked()
            }

            DispatchQueue.main.async {
                hud.hide()
                PayWindow.instance().render(asset: asset, action: .multisig(multisig: multisig, senders: senderUsers, receivers: receiverUsers), amount: multisig.amount, memo: "", error: error).presentPopupControllerAnimated()
            }
        }
    }

    private static func presentPayment(payment: PaymentCodeResponse, hud: Hud) {
        guard LoginManager.shared.account?.has_pin ?? false else {
            UIApplication.homeNavigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: nil), animated: true)
            DispatchQueue.main.async {
                hud.hide()
            }
            return
        }
        DispatchQueue.global().async {
            guard let asset = syncAsset(assetId: payment.assetId, hud: hud) else {
                return
            }
            guard let users = syncUsers(userIds: payment.receivers, hud: hud) else {
                return
            }

            let receiverUsers = users.filter { payment.receivers.contains($0.userId) }
            let error = payment.status == PaymentStatus.paid.rawValue ? R.string.localizable.transfer_paid() : ""

            DispatchQueue.main.async {
                hud.hide()
                PayWindow.instance().render(asset: asset, action: .payment(payment: payment, receivers: receiverUsers), amount: payment.amount, memo: "", error: error).presentPopupControllerAnimated()
            }
        }
    }

    private static func presentUser(user: UserResponse, hud: Hud) {
        DispatchQueue.global().async {
            UserDAO.shared.updateUsers(users: [user])

            DispatchQueue.main.async {
                hud.hide()
                let user = UserItem.createUser(from: user)
                let vc = UserProfileViewController(user: user)
                UIApplication.homeContainerViewController?.present(vc, animated: true, completion: nil)
            }
        }
    }

    private static func presentAuthorization(authorization: AuthorizationResponse, webContext: MixinWebViewController.Context? = nil, hud: Hud) {
        if let context = webContext,  case let .app(app, _) = context.style {
            Logger.write(log: "[Authorization][WebContext][\(app.appNumber)][\(app.name)]...\(app.homeUri)")
        } else {
            Logger.write(log: "[Authorization][\(authorization.app.appNumber)][\(authorization.app.name)]...\(authorization.app.homeUri)")
        }
        
        if let window = UIApplication.shared.keyWindow?.subviews.compactMap({ $0 as? AuthorizationWindow }).first, window.isShowing {
            hud.hideInMainThread()
            return
        }
        
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
            let subParticipants = conversation.participants.prefix(4)
            let accountUserId = myUserId
            let conversationId = conversation.conversationId
            let isMember = conversation.participants.first(where: { $0.userId == accountUserId }) != nil
            let userIds = subParticipants.map{ $0.userId }
            var participants = [ParticipantUser]()
            switch UserAPI.showUsers(userIds: userIds) {
            case let .success(users):
                participants = users.map {
                    ParticipantUser(conversationId: conversationId, user: $0)
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
                return
            }
            var creatorUser = UserDAO.shared.getUser(userId: conversation.creatorId)
            if creatorUser == nil {
                switch UserAPI.showUser(userId: conversation.creatorId) {
                case let .success(user):
                    creatorUser = UserItem.createUser(from: user)
                case let .failure(error):
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                    return
                }
            }
            
            if isMember && ConversationDAO.shared.getConversationStatus(conversationId: conversation.conversationId) != ConversationStatus.SUCCESS.rawValue {
                ConversationDAO.shared.createConversation(conversation: conversation, targetStatus: .SUCCESS)
            }
            
            DispatchQueue.main.async {
                hud.hide()
                if isMember {
                    let vc = ConversationViewController.instance(conversation: ConversationItem(response: conversation))
                    UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
                } else {
                    let vc = GroupProfileViewController(response: conversation, codeId: codeId, participants: participants, isMember: isMember)
                    UIApplication.homeContainerViewController?.present(vc, animated: true, completion: nil)
                }
                
            }
        }
    }
}

extension Array where Element: Hashable {
    
    func filterDuplicates() -> [Element] {
        var uniq = Set<Element>()
        uniq.reserveCapacity(count)
        return filter { uniq.insert($0).inserted }
    }
    
    func symmetricDifference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
}
