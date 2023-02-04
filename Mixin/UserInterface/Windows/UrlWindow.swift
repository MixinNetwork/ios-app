import Foundation
import UIKit
import Alamofire
import MixinServices

class UrlWindow {
    
    enum SyncError: Error {
        case invalidAddress
    }
    
    class func checkUrl(
        url: URL,
        webContext: MixinWebViewController.Context? = nil,
        clearNavigationStack: Bool = true,
        presentHintOnUnsupportedMixinSchema: Bool = true
    ) -> Bool {
        if let mixinURL = MixinURL(url: url) {
            let result: Bool
            switch mixinURL {
            case let .codes(code):
                result = checkCodesUrl(code, clearNavigationStack: clearNavigationStack, webContext: webContext)
            case .pay:
                if let transfer = try? InternalTransfer(string: url.absoluteString) {
                    performInternalTransfer(transfer)
                    result = true
                } else {
                    result = false
                }
            case .withdrawal:
                result = checkWithdrawal(url: url)
            case .address:
                result = checkAddress(url: url)
            case let .users(id):
                result = checkUser(id, clearNavigationStack: clearNavigationStack)
            case .snapshots:
                result = checkSnapshot(url: url)
            case let .conversations(conversationId, userId):
                result = checkConversation(conversationId: conversationId, userId: userId)
            case let .apps(userId):
                result = checkApp(url: url, userId: userId)
            case let .transfer(id):
                result = checkTransferUrl(id, clearNavigationStack: clearNavigationStack)
            case let .send(context):
                result = checkSendUrl(sharingContext: context, webContext: webContext)
            case let .device(id, publicKey):
                checkDevice(id: id, publicKey: publicKey)
                result = true
            case .upgradeDesktop:
                UIApplication.currentActivity()?.alert(R.string.localizable.desktop_upgrade())
                result = true
            case .unknown:
                if presentHintOnUnsupportedMixinSchema && url.scheme == MixinURL.scheme {
                    UnknownURLWindow.instance().render(url: url).presentPopupControllerAnimated()
                    result = true
                } else {
                    result = false
                }
            }
            if !result && presentHintOnUnsupportedMixinSchema && url.scheme == MixinURL.scheme {
                UnknownURLWindow.instance().render(url: url).presentPopupControllerAnimated()
                return true
            } else {
                return result
            }
        } else if let url = MixinInternalURL(url: url) {
            switch url {
            case let .identityNumber(number):
                return checkUser(identityNumber: number)
            case let .phoneNumber(number):
                let sheet = UIAlertController(title: number, message: nil, preferredStyle: .actionSheet)
                sheet.addAction(UIAlertAction(title: R.string.localizable.phone_call(), style: .default, handler: { _ in
                    let url = URL(string: "tel://\(number)")!
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }))
                sheet.addAction(UIAlertAction(title: R.string.localizable.copy(), style: .default, handler: { _ in
                    UIPasteboard.general.string = number
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
                }))
                sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
                UIApplication.homeContainerViewController?.present(sheet, animated: true, completion: nil)
                return true
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
                    let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.bot_not_found())
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
                    showAutoHiddenHud(style: .error, text: R.string.localizable.bot_not_found())
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
        
        func pushConversationViewController(user: UserItem? = nil, conversation: ConversationItem? = nil) {
            let pushController = {
                let viewController: UIViewController?
                if let user = user {
                    viewController = ConversationViewController.instance(ownerUser: user)
                } else if let conversation = conversation {
                    viewController = ConversationViewController.instance(conversation: conversation)
                } else {
                    viewController = nil
                }
                if let viewController = viewController {
                    UIApplication.homeNavigationController?.pushViewController(withBackRoot: viewController)
                }
            }
            if let container = UIApplication.homeContainerViewController, container.galleryIsOnTopMost {
                let currentItemViewController = container.galleryViewController.currentItemViewController
                if let vc = currentItemViewController as? GalleryVideoItemViewController {
                    vc.togglePipMode(completion: {
                        DispatchQueue.main.async(execute: pushController)
                    })
                } else {
                    container.galleryViewController.dismiss(transitionViewInitialOffsetY: 0)
                    pushController()
                }
            } else {
                pushController()
            }
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
                    pushConversationViewController(user: user)
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
                    pushConversationViewController(conversation: conversation)
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
            guard let user = userItem else {
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

    class func checkDevice(id: String, publicKey: String) {
        switch TIP.status {
        case .ready, .needsMigrate:
            LoginConfirmWindow.instance().render(id: id, publicKey: publicKey).presentView()
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: nil)
            UIApplication.homeNavigationController?.present(tip, animated: true)
        case .unknown:
            break
        }
    }
    
    class func checkWithdrawal(url: URL) -> Bool {
        switch TIP.status {
        case .ready, .needsMigrate:
            break
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: nil)
            UIApplication.homeNavigationController?.present(tip, animated: true)
            return true
        case .unknown:
            return true
        }
        let query = url.getKeyVals()
        guard let assetId = query["asset"], let amount = query["amount"], let traceId = query["trace"], let addressId = query["address"] else {
            return false
        }
        guard !assetId.isEmpty && UUID(uuidString: assetId) != nil && !traceId.isEmpty && UUID(uuidString: traceId) != nil && !addressId.isEmpty && UUID(uuidString: addressId) != nil && !amount.isEmpty && AmountFormatter.isValid(amount) else {
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
                Logger.general.error(category: "UrlWindow", message: "Failed to sync asset for url: \(url.absoluteString)")
                return
            }
            guard let address = syncAddress(addressId: addressId, hud: hud) else {
                return
            }
            guard let feeAsset = syncAsset(assetId: address.feeAssetId, hud: hud) else {
                Logger.general.error(category: "UrlWindow", message: "Failed to sync fee asset for url: \(url.absoluteString)")
                return
            }
            
            let action: PayWindow.PinAction = .withdraw(trackId: traceId, address: address, feeAsset: feeAsset, fromWeb: true)
            PayWindow.checkPay(traceId: traceId, asset: asset, action: action, destination: address.destination, tag: address.tag, addressId: address.addressId, amount: amount, memo: memo ?? "", fromWeb: true) { (canPay, errorMsg) in

                DispatchQueue.main.async {
                    if canPay {
                        hud.hide()
                        PayWindow.instance().render(asset: asset, action: action, amount: amount, memo: memo ?? "").presentPopupControllerAnimated()
                    } else if let error = errorMsg {
                        Logger.general.error(category: "UrlWindow", message: "Unable to pay for url: \(url.absoluteString)")
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

    class func checkQrCodeDetection(string: String, clearNavigationStack: Bool = true) {
        if checkPayment(string: string) {
            return
        }
        if checkExternalScheme(url: string) {
            return
        }
        if let url = URL(string: string), checkUrl(url: url, clearNavigationStack: clearNavigationStack) {
            return
        }
        RecognizeWindow.instance().presentWindow(text: string)
    }
    
    class func checkPayment(string: String) -> Bool {
        do {
            let transfer = try InternalTransfer(string: string)
            performInternalTransfer(transfer)
            return true
        } catch TransferLinkError.notTransferLink {
            do {
                let transfer = try ExternalTransfer(string: string)
                performExternalTransfer(transfer)
                return true
            } catch TransferLinkError.notTransferLink {
                return false
            } catch {
                Logger.general.error(category: "URLWindow", message: "Invalid payment: \(string)")
                showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
                return true
            }
        } catch {
            Logger.general.error(category: "URLWindow", message: "Invalid payment: \(string)")
            showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
            return true
        }
    }
    
    class func performInternalTransfer(_ transfer: InternalTransfer) {
        switch TIP.status {
        case .ready, .needsMigrate:
            break
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: nil)
            UIApplication.homeNavigationController?.present(tip, animated: true)
            return
        case .unknown:
            return
        }
        let memo = transfer.memo ?? ""
        let traceId = transfer.traceID
        let recipientId = transfer.recipientID
        let amount = transfer.amount
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            guard let asset = syncAsset(assetId: transfer.assetID, hud: hud) else {
                return
            }
            guard let (user, _) = syncUser(userId: recipientId, hud: hud) else {
                return
            }
            let action: PayWindow.PinAction = .transfer(trackId: traceId, user: user, fromWeb: true, returnTo: transfer.returnTo)
            PayWindow.checkPay(traceId: traceId, asset: asset, action: action, opponentId: recipientId, amount: amount, memo: memo, fromWeb: true) { (canPay, errorMsg) in
                DispatchQueue.main.async {
                    if canPay {
                        hud.hide()
                        PayWindow.instance().render(asset: asset, action: action, amount: amount, isAmountLocalized: false, memo: memo).presentPopupControllerAnimated()
                    } else if let error = errorMsg {
                        hud.set(style: .error, text: error)
                        hud.scheduleAutoHidden()
                    } else {
                        hud.hide()
                    }
                }
            }
        }
    }
    
    class func performExternalTransfer(_ transfer: ExternalTransfer) {
        switch TIP.status {
        case .ready, .needsMigrate:
            break
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: nil)
            UIApplication.homeNavigationController?.present(tip, animated: true)
            return
        case .unknown:
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            let resolvedAmount: String
            if let amount = transfer.resolvedAmount {
                resolvedAmount = amount
            } else {
                switch AssetAPI.assetPrecision(assetId: transfer.assetID) {
                case let .success(response):
                    resolvedAmount = ExternalTransfer.resolve(atomicAmount: transfer.amount, with: response.precision)
                case let .failure(error):
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                    return
                }
            }
            if let arbitraryAmount = transfer.arbitraryAmount, arbitraryAmount != resolvedAmount {
                DispatchQueue.main.async {
                    hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                    hud.scheduleAutoHidden()
                }
                return
            }
            let assetId = transfer.assetID
            let memo = transfer.memo ?? ""
            guard let asset = syncAsset(assetId: assetId, hud: hud) else {
                Logger.general.error(category: "UrlWindow", message: "Failed to sync asset for url: \(transfer.raw)")
                hud.hideInMainThread()
                return
            }
            switch ExternalSchemeAPI.checkAddress(assetId: assetId, destination: transfer.destination, tag: nil) {
            case .success(let response):
                guard response.tag.isNilOrEmpty, transfer.destination.lowercased() == response.destination.lowercased() else {
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                        hud.scheduleAutoHidden()
                    }
                    return
                }
                guard let feeAsset = syncAsset(assetId: response.feeAssetId, hud: hud) else {
                    Logger.general.error(category: "UrlWindow", message: "Failed to sync fee asset for url: \(transfer.raw)")
                    hud.hideInMainThread()
                    return
                }
                let destination = response.destination
                let traceId = UUID().uuidString.lowercased()
                let addressId = (myUserId + assetId + destination).uuidDigest()
                let action: PayWindow.PinAction = .externalTransfer(destination: destination, fee: response.fee, feeAsset: feeAsset, addressId: addressId, traceId: traceId)
                PayWindow.checkPay(traceId: traceId, asset: asset, action: action, destination: destination, tag: nil, addressId: nil, amount: resolvedAmount, memo: memo, fromWeb: true) { (canPay, errorMsg) in
                    DispatchQueue.main.async {
                        if canPay {
                            hud.hide()
                            PayWindow.instance().render(asset: asset, action: action, amount: resolvedAmount, isAmountLocalized: false, memo: memo).presentPopupControllerAnimated()
                        } else if let error = errorMsg {
                            Logger.general.error(category: "UrlWindow", message: "Unable to pay for url: \(transfer.raw)")
                            hud.set(style: .error, text: error)
                            hud.scheduleAutoHidden()
                        } else {
                            hud.hide()
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        }
    }
    
    class func checkAddress(url: URL) -> Bool {
        switch TIP.status {
        case .ready, .needsMigrate:
            break
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: nil)
            UIApplication.homeNavigationController?.present(tip, animated: true)
            return true
        case .unknown:
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

            while asset.depositEntries.isEmpty {
                switch AssetAPI.asset(assetId: asset.assetId) {
                case let .success(remoteAsset):
                    guard !remoteAsset.depositEntries.isEmpty else {
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
            func present(action: ExternalSharingConfirmationViewController.Action) {
                let vc = R.storyboard.chat.external_sharing_confirmation()!
                vc.modalPresentationStyle = .custom
                vc.transitioningDelegate = PopupPresentationManager.shared
                UIApplication.homeContainerViewController?.present(vc, animated: true, completion: nil)
                vc.load(sharingContext: sharingContext, message: message, webContext: webContext, action: action)
            }
            if !sharingContext.conversationId.isNilOrEmpty && sharingContext.conversationId == UIApplication.currentConversationId() {
                DispatchQueue.global().async {
                    guard let conversation = ConversationDAO.shared.getConversation(conversationId: message.conversationId) else {
                        hud.hideInMainThread()
                        return
                    }
                    guard let (ownerUser, _) = syncUser(userId: conversation.ownerId, hud: hud) else {
                        hud.hideInMainThread()
                        return
                    }
                    DispatchQueue.main.async {
                        hud.hide()
                        present(action: .send(conversation: conversation, ownerUser: ownerUser))
                    }
                }
            } else {
                hud.hide()
                present(action: .forward)
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
                    message.thumbImage = image.blurHash()
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
        case let .sticker(stickerId, _):
            DispatchQueue.global().async {
                let isAdded: Bool
                if let sticker = StickerDAO.shared.getSticker(stickerId: stickerId), !sticker.assetUrl.isEmpty {
                    message.mediaUrl = sticker.assetUrl
                    isAdded = sticker.isAdded
                } else if case let .success(sticker) = StickerAPI.sticker(stickerId: stickerId), !sticker.assetUrl.isEmpty {
                    message.mediaUrl = sticker.assetUrl
                    isAdded = false
                } else {
                    hud.hideInMainThread()
                    return
                }
                DispatchQueue.main.async {
                    sharingContext.content = .sticker(stickerId, isAdded)
                    presentSendingConfirmation()
                }
            }
        default:
            DispatchQueue.main.async {
                presentSendingConfirmation()
            }
        }
        return true
    }
    
    class func checkExternalScheme(url: String) -> Bool {
        guard let url = URL(string: url), let host = url.host else {
            return false
        }
        let externalSchemeHosts = AppGroupUserDefaults.User.externalSchemes
            .compactMap(URL.init)
            .compactMap(\.host)
        if externalSchemeHosts.contains(host) {
            guard let container = UIApplication.homeContainerViewController else {
                return false
            }
            var parent = container.topMostChild
            if let visibleViewController = (parent as? UINavigationController)?.visibleViewController {
                parent = visibleViewController
            }
            MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url), asChildOf: parent)
            return true
        }
        return false
    }
    
    class func checkDeepLinking(url: URL) -> Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        if ScreenLockManager.shared.isLocked {
            ScreenLockManager.shared.screenLockViewDidHide = {
                _ = checkUrl(url: url, presentHintOnUnsupportedMixinSchema: false)
                ScreenLockManager.shared.screenLockViewDidHide = nil
            }
            return true
        } else {
            return checkUrl(url: url, presentHintOnUnsupportedMixinSchema: false)
        }
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
                } else if let collectible = code.collectible {
                    presentCollectible(collectible: collectible, hud: hud)
                } else if let payment = code.payment {
                    presentPayment(payment: payment, hud: hud)
                } else {
                    hud.hide()
                }
            case let .failure(error):
                let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.unrecognized_codes())
                hud.set(style: .error, text: text)
                hud.scheduleAutoHidden()
            }
        }
        return true
    }

    private static func syncAddress(addressId: String, hud: Hud) -> Address? {
        let address: Address
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
        if address.feeAssetId.isEmpty {
            DispatchQueue.main.async {
                hud.set(style: .error, text: R.string.localizable.address_not_found())
                hud.scheduleAutoHidden()
            }
            reporter.report(error: SyncError.invalidAddress)
        }
        return address
    }
    
    private static func syncAsset(assetId: String, hud: Hud) -> AssetItem? {
        var asset = AssetDAO.shared.getAsset(assetId: assetId)
        if asset == nil {
            switch AssetAPI.asset(assetId: assetId) {
            case let .success(assetItem):
                asset = AssetDAO.shared.saveAsset(asset: assetItem)
                if asset == nil {
                    Logger.general.error(category: "UrlWindow", message: "No asset: \(assetId) from local")
                }
            case let .failure(error):
                Logger.general.error(category: "UrlWindow", message: "No asset: \(assetId) from remote, error: \(error)")
                let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.asset_not_found())
                DispatchQueue.main.async {
                    hud.set(style: .error, text: text)
                    hud.scheduleAutoHidden()
                }
                return nil
            }
        }
        if let asset, asset.assetId != asset.chainId {
            let chainAsset = syncAsset(assetId: asset.chainId, hud: hud)
            if chainAsset == nil {
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
    
    private static func collectibleToken(tokenId: String, hud: Hud) -> CollectibleToken? {
        switch CollectibleAPI.token(tokenId: tokenId) {
        case let .success(token):
            return token
        case let .failure(error):
            let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.asset_not_found())
            DispatchQueue.main.async {
                hud.set(style: .error, text: text)
                hud.scheduleAutoHidden()
            }
            return nil
        }
    }
    
    private static func presentMultisig(multisig: MultisigResponse, hud: Hud) {
        switch TIP.status {
        case .ready, .needsMigrate:
            break
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: nil)
            UIApplication.homeNavigationController?.present(tip, animated: true)
            fallthrough
        case .unknown:
            DispatchQueue.main.async(execute: hud.hide)
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
        switch TIP.status {
        case .ready, .needsMigrate:
            break
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: nil)
            UIApplication.homeNavigationController?.present(tip, animated: true)
            fallthrough
        case .unknown:
            DispatchQueue.main.async(execute: hud.hide)
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
            let error = payment.status == PaymentStatus.paid.rawValue ? R.string.localizable.pay_paid() : ""

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

    private static func presentCollectible(collectible: CollectibleResponse, hud: Hud) {
        switch TIP.status {
        case .ready, .needsMigrate:
            break
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: nil)
            UIApplication.homeNavigationController?.present(tip, animated: true)
            fallthrough
        case .unknown:
            DispatchQueue.main.async(execute: hud.hide)
            return
        }
        DispatchQueue.global().async {
            guard let token = collectibleToken(tokenId: collectible.tokenId, hud: hud) else {
                return
            }
            guard let users = syncUsers(userIds: collectible.senders + collectible.receivers, hud: hud) else {
                return
            }
            let senderUsers = users.filter { collectible.senders.contains($0.userId) }
            let receiverUsers = users.filter { collectible.receivers.contains($0.userId) }
            var error = ""
            if collectible.action == CollectibleAction.sign.rawValue && collectible.state == CollectibleState.signed.rawValue {
                error = R.string.localizable.multisig_state_signed()
            } else if collectible.action == CollectibleAction.unlock.rawValue && collectible.state == CollectibleState.unlocked.rawValue {
                error = R.string.localizable.multisig_state_unlocked()
            }
            DispatchQueue.main.async {
                hud.hide()
                PayWindow.instance().render(token: token, action: .collectible(collectible: collectible, senders: senderUsers, receivers: receiverUsers), amount: collectible.amount, memo: "", error: error).presentPopupControllerAnimated()
            }
        }
    }
    
    private static func presentAuthorization(authorization: AuthorizationResponse, webContext: MixinWebViewController.Context? = nil, hud: Hud) {
        if let context = webContext,  case let .app(app, _) = context.style {
            if let switcher = UIApplication.homeContainerViewController?.clipSwitcher, let clip = switcher.clips.first(where: { $0.app?.appId == app.appId }) {
                Logger.general.info(category: "Authorization", message: "Auth window presented from clip: \(clip.title), url: \(clip.url)")
            }
            Logger.general.info(category: "Authorization", message: "Auth window presented with web context. App number: \(app.appNumber), name: \(app.name), home: \(app.homeUri)")
        } else {
            Logger.general.info(category: "Authorization", message: "Auth window presented with app number: \(authorization.app.appNumber), name: \(authorization.app.name), home: \(authorization.app.homeUri)")
        }
        
        if let window = UIApplication.shared.keyWindow?.subviews.compactMap({ $0 as? AuthorizationWindow }).first, window.isShowing {
            hud.hideInMainThread()
            return
        }
        hud.hide()
        AuthorizationWindow.instance().render(authInfo: authorization).presentPopupControllerAnimated()
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
