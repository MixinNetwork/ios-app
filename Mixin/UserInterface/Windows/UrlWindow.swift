import Foundation
import UIKit
import Alamofire
import WalletConnectUtils
import Web3Wallet
import MixinServices

class UrlWindow {
    
    enum Source {
        
        case openURL
        case userActivity
        case webView(MixinWebViewController.Context)
        case conversation(WeakWrapper<ConversationMessageComposer>)
        case other
        
        var webContext: MixinWebViewController.Context? {
            switch self {
            case .webView(let context):
                return context
            default:
                return nil
            }
        }
        
        var isExternal: Bool {
            switch self {
            case .openURL, .userActivity, .conversation:
                return true
            case .webView, .other:
                return false
            }
        }
        
    }
    
    class func checkUrl(
        url: URL,
        from source: Source = .other,
        clearNavigationStack: Bool = true
    ) -> Bool {
        if let object = SafeURL(url: url) {
            // When a payment is invoked by a URL, the outputs may not in sync, potentially causing
            // payment failures due to inaccurate balance. However, this synchronization lacks ordering
            // guarantees, so the issue still occurs in some circumstances.
            switch object {
            case .payment(let payment):
                let job = SyncOutputsJob()
                ConcurrentJobQueue.shared.addJob(job: job)
                checkSafePaymentURL(payment, from: source)
                return true
            case .multisig(let multisig):
                checkMultisig(multisig)
                return true
            case .code(let code):
                let job = SyncOutputsJob()
                ConcurrentJobQueue.shared.addJob(job: job)
                checkCode(code, from: source, clearNavigationStack: clearNavigationStack)
                return true
            case .tip(let tip):
                checkTIP(tip, from: source)
                return true
            }
        } else if let mixinURL = MixinURL(url: url) {
            let result: Bool
            switch mixinURL {
            case let .codes(code):
                result = checkCodesUrl(code, clearNavigationStack: clearNavigationStack, webContext: source.webContext)
            case .pay:
                if let transfer = try? LegacyInternalTransfer(string: url.absoluteString) {
                    performInternalTransfer(transfer)
                    result = true
                } else {
                    result = false
                }
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
                result = checkSendUrl(sharingContext: context, webContext: source.webContext)
            case let .device(id, publicKey):
                checkDevice(id: id, publicKey: publicKey)
                result = true
            case .upgradeDesktop:
                UIApplication.currentActivity()?.alert(R.string.localizable.desktop_upgrade())
                result = true
            case let .deviceTransfer(command):
                result = checkDeviceTransfer(command: command)
            case let .walletConnect(uri):
                if let uri {
                    WalletConnectService.shared.connect(to: uri)
                    return true
                } else {
                    // Reject undocumented URIs. See `MixinURL.walletConnect` for details
                    return false
                }
            case .unknown:
                if source.isExternal && url.scheme == MixinURL.scheme {
                    UnknownURLWindow.instance().render(url: url).presentPopupControllerAnimated()
                    result = true
                } else {
                    result = false
                }
            }
            if !result && source.isExternal && url.scheme == MixinURL.scheme {
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
                    let vc = LegacyTransactionViewController.instance(asset: assetItem, snapshot: snapshot)
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
                    let vc = LegacyTransferOutViewController.instance(asset: nil, type: .contact(user))
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
    
    class func checkQrCodeDetection(string: String, clearNavigationStack: Bool = true) {
        if checkWithdrawal(string: string) {
            return
        }
        if checkExternalScheme(url: string) {
            return
        }
        if let url = URL(string: string), checkUrl(url: url, clearNavigationStack: clearNavigationStack) {
            return
        }
        if let uri = try? WalletConnectURI(uriString: string) {
            switch TIP.status {
            case .ready:
                WalletConnectService.shared.connect(to: uri)
                return
            case .needsInitialize:
                let tip = TIPNavigationViewController(intent: .create, destination: nil)
                UIApplication.homeNavigationController?.present(tip, animated: true)
                return
            case .unknown, .needsMigrate:
                break
            }
        }
        RecognizeWindow.instance().presentWindow(text: string)
    }
    
    class func checkWithdrawal(string: String) -> Bool {
        do {
            let transfer = try ExternalTransfer(string: string)
            performExternalTransfer(transfer)
            return true
        } catch TransferLinkError.notTransferLink {
            return false
        } catch TransferLinkError.assetNotFound {
            Logger.general.error(category: "URLWindow", message: "Asset not found: \(string)")
            showAutoHiddenHud(style: .error, text: R.string.localizable.asset_not_found())
            return true
        } catch {
            Logger.general.error(category: "URLWindow", message: "Invalid payment: \(string)")
            showAutoHiddenHud(style: .error, text: R.string.localizable.invalid_payment_link())
            return true
        }
    }
    
    class func performInternalTransfer(_ transfer: LegacyInternalTransfer) {
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
        guard let homeContainer = UIApplication.homeContainerViewController else {
            return
        }
        
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
        
        enum Error: Swift.Error, LocalizedError {
            
            case invalidPaymentLink
            case syncTokenFailed
            case insufficientBalance
            case insufficientFee
            
            var errorDescription: String? {
                switch self {
                case .invalidPaymentLink:
                    R.string.localizable.invalid_payment_link()
                case .syncTokenFailed:
                    R.string.localizable.error_connection_timeout()
                case .insufficientBalance:
                    R.string.localizable.insufficient_balance()
                case .insufficientFee:
                    R.string.localizable.insufficient_transaction_fee()
                }
            }
            
        }
        
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        Task {
            do {
                let resolvedAmount: Decimal
                if let amount = transfer.resolvedAmount {
                    resolvedAmount = amount
                } else {
                    let precision = try await AssetAPI.assetPrecision(assetID: transfer.assetID).precision
                    resolvedAmount = ExternalTransfer.resolve(atomicAmount: transfer.amount, with: precision)
                }
                if let arbitraryAmount = transfer.arbitraryAmount, arbitraryAmount != resolvedAmount {
                    throw Error.invalidPaymentLink
                }
                
                let assetID = transfer.assetID
                guard let token = syncToken(assetID: assetID, hud: hud) else {
                    throw Error.syncTokenFailed
                }
                guard resolvedAmount <= token.decimalBalance else {
                    throw Error.insufficientBalance
                }
                
                let response = try await ExternalAPI.checkAddress(assetID: assetID, destination: transfer.destination, tag: nil)
                guard response.tag.isNilOrEmpty, transfer.destination.lowercased() == response.destination.lowercased() else {
                    throw Error.invalidPaymentLink
                }
                let address = TemporaryAddress(destination: response.destination, tag: response.tag ?? "")
                
                let fees = try await SafeAPI.fees(assetID: assetID, destination: address.destination)
                guard !fees.isEmpty else {
                    throw MixinAPIResponseError.withdrawSuspended
                }
                let feeItems: [WithdrawFeeItem] = try fees.lazy.compactMap { fee in
                    guard let feeToken = syncToken(assetID: fee.assetID, hud: hud) else {
                        throw Error.syncTokenFailed
                    }
                    guard let feeItem = WithdrawFeeItem(amountString: fee.amount, tokenItem: feeToken) else {
                        return nil
                    }
                    let isFeeSufficient = if feeToken.assetID == assetID {
                        (resolvedAmount + feeItem.amount) <= feeToken.decimalBalance
                    } else {
                        feeItem.amount <= feeToken.decimalBalance
                    }
                    return isFeeSufficient ? feeItem : nil
                }
                guard let feeItem = feeItems.first else {
                    throw Error.insufficientFee
                }
                
                let traceID = UUID().uuidString.lowercased()
                let fiatMoneyAmount = resolvedAmount * token.decimalUSDPrice * Decimal(Currency.current.rate)
                let payment = Payment(traceID: traceID, token: token, tokenAmount: resolvedAmount, fiatMoneyAmount: fiatMoneyAmount, memo: transfer.memo ?? "")
                payment.checkPreconditions(withdrawTo: .temporary(address), fee: feeItem, on: homeContainer) { reason in
                    switch reason {
                    case .userCancelled:
                        hud.hide()
                    case .description(let message):
                        hud.set(style: .error, text: message)
                        hud.scheduleAutoHidden()
                    }
                } onSuccess: { (operation, issues) in
                    hud.hide()
                    let preview = WithdrawPreviewViewController(issues: issues,
                                                                operation: operation,
                                                                amountDisplay: .byToken,
                                                                withdrawalTokenAmount: resolvedAmount,
                                                                withdrawalFiatMoneyAmount: fiatMoneyAmount,
                                                                addressLabel: nil)
                    preview.manipulateNavigationStackOnFinished = false
                    homeContainer.present(preview, animated: true)
                }
            } catch {
                await MainActor.run {
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
        let queries = url.getKeyVals()
        guard let assetID = queries["asset"], UUID.isValidLowercasedUUIDString(assetID) else {
            return false
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            guard let token = syncToken(assetID: assetID, hud: hud) else {
                return
            }
            if queries["action"]?.lowercased() == "delete" {
                guard let addressID = queries["address"], UUID.isValidLowercasedUUIDString(addressID) else {
                    hud.hideInMainThread()
                    return
                }
                var address = AddressDAO.shared.getAddress(addressId: addressID)
                if address == nil {
                    switch AddressAPI.address(addressID: addressID) {
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
                DispatchQueue.main.async {
                    if let address {
                        hud.hide()
                        let preview = EditAddressPreviewViewController(token: token,
                                                                       label: address.label,
                                                                       destination: address.destination,
                                                                       tag: address.tag,
                                                                       action: .delete(id: address.addressId))
                        UIApplication.homeContainerViewController?.present(preview, animated: true)
                    } else {
                        hud.set(style: .error, text: R.string.localizable.address_not_found())
                        hud.scheduleAutoHidden()
                    }
                }
            } else if let label = queries["label"], let destination = queries["destination"], !label.isEmpty, !destination.isEmpty {
                let tag = queries["tag"] ?? ""
                let address = AddressDAO.shared.getAddress(assetId: assetID, destination: destination, tag: tag)
                DispatchQueue.main.async {
                    hud.hide()
                    let preview = EditAddressPreviewViewController(token: token,
                                                                   label: label,
                                                                   destination: destination,
                                                                   tag: tag,
                                                                   action: address == nil ? .add : .update)
                    UIApplication.homeContainerViewController?.present(preview, animated: true)
                }
            } else {
                hud.hideInMainThread()
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
                vc.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
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
    
    class func checkURLNowOrAfterScreenUnlocked(url: URL, from source: Source) -> Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        if ScreenLockManager.shared.isLocked {
            ScreenLockManager.shared.screenLockViewDidHide = {
                _ = checkUrl(url: url, from: source)
                ScreenLockManager.shared.screenLockViewDidHide = nil
            }
            return true
        } else {
            return checkUrl(url: url, from: source)
        }
    }
    
    class func checkDeviceTransfer(command: DeviceTransferCommand) -> Bool {
        guard AppGroupUserDefaults.Account.canRestoreFromPhone else {
            return true
        }
        guard command.version == DeviceTransferCommand.localVersion else {
            UIApplication.currentActivity()?.alert(R.string.localizable.transfer_protocol_version_not_matched())
            return true
        }
        guard case let .push(context) = command.action else {
            UIApplication.currentActivity()?.alert(R.string.localizable.transfer_protocol_version_not_matched())
            return true
        }
        guard context.userID == myUserId else {
            UIApplication.currentActivity()?.alert(R.string.localizable.unable_synced_between_different_account())
            return true
        }
        let client = DeviceTransferClient(hostname: context.hostname,
                                          port: context.port,
                                          code: context.code,
                                          key: context.key,
                                          remotePlatform: command.platform)
        client.start()
        let progress = DeviceTransferProgressViewController(connection: .client(client, .phone))
        if let navigationController = AppDelegate.current.mainWindow.rootViewController as? UINavigationController {
            navigationController.pushViewController(progress, animated: true)
        } else {
            AppDelegate.current.mainWindow.rootViewController?.present(progress, animated: true)
        }
        return true
    }
    
}

extension UrlWindow {

    private static func checkSafePaymentURL(_ paymentURL: SafePaymentURL, from source: Source) {
        guard let homeContainer = UIApplication.homeContainerViewController else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: homeContainer.view)
        DispatchQueue.global().async {
            let destination: Payment.TransferDestination
            switch paymentURL.address {
            case let .user(id):
                guard let items = syncUsers(userIds: [id], hud: hud) else {
                    return
                }
                if let item = items.first {
                    destination = .user(item)
                } else {
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                        hud.scheduleAutoHidden()
                    }
                    return
                }
            case let .multisig(threshold, ids):
                guard let users = syncUsersInOrder(userIDs: ids, hud: hud) else {
                    return
                }
                if users.count == 1 {
                    destination = .user(users[0])
                } else {
                    destination = .multisig(threshold: threshold, users: users)
                }
            case let .mainnet(address):
                destination = .mainnet(address)
            }
            
            let payment: Payment
            switch paymentURL.request {
            case .notDetermined:
                DispatchQueue.main.async {
                    let transfer: UIViewController
                    switch destination {
                    case .user(let user):
                        transfer = TransferOutViewController.instance(token: nil, to: .contact(user))
                    case .multisig:
                        hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                        hud.scheduleAutoHidden()
                        return
                    case .mainnet(let address):
                        transfer = TransferOutViewController.instance(token: nil, to: .mainnet(address))
                    }
                    hud.hide()
                    UIApplication.homeNavigationController?.pushViewController(transfer, animated: true)
                }
                return
            case let .inscription(hash):
                guard let (output, inscriptionItem) = syncInscriptionOutput(inscriptionHash: hash, hud: hud) else {
                    return
                }
                guard let outputAmount = output.decimalAmount else {
                    Logger.general.error(category: "UrlWindow", message: "Invalid output amount: \(output.amount)")
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: "Invalid Output")
                        hud.scheduleAutoHidden()
                    }
                    return
                }
                guard let assetID = TokenDAO.shared.assetID(kernelAssetID: output.asset) else {
                    Logger.general.warn(category: "UrlWindow", message: "Missing output asset: \(output.asset)")
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: "Missing Asset")
                        hud.scheduleAutoHidden()
                    }
                    return
                }
                let context: Payment.InscriptionContext
                switch paymentURL.amount {
                case .some(let amount):
                    if amount == outputAmount {
                        // Transfer
                        context = .init(operation: .transfer, output: output, outputAmount: outputAmount, item: inscriptionItem)
                    } else if amount > 0 && amount < outputAmount {
                        // Release
                        guard let asset = paymentURL.asset, asset == assetID else {
                            Logger.general.warn(category: "UrlWindow", message: "Mismatched asset: \(paymentURL.asset ?? "(null)") \(assetID)")
                            DispatchQueue.main.async {
                                hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                                hud.scheduleAutoHidden()
                            }
                            return
                        }
                        guard case let .user(item) = destination, item.relationship == Relationship.ME.rawValue else {
                            Logger.general.warn(category: "UrlWindow", message: "Releasing to others")
                            DispatchQueue.main.async {
                                hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                                hud.scheduleAutoHidden()
                            }
                            return
                        }
                        context = .release(amount: .half, output: output, outputAmount: outputAmount, item: inscriptionItem)
                    } else {
                        Logger.general.error(category: "UrlWindow", message: "Invalid amount from URL: \(amount)")
                        DispatchQueue.main.async {
                            hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                            hud.scheduleAutoHidden()
                        }
                        return
                    }
                case .none:
                    // Transfer
                    context = Payment.InscriptionContext(operation: .transfer, output: output, outputAmount: outputAmount, item: inscriptionItem)
                }
                guard let token = syncToken(assetID: assetID, hud: hud) else {
                    return
                }
                payment = .inscription(traceID: paymentURL.trace,
                                       token: token,
                                       memo: paymentURL.memo,
                                       context: context)
            case let .prefilled(assetID, amount):
                guard let token = syncToken(assetID: assetID, hud: hud) else {
                    return
                }
                let fiatMoneyAmount = amount * token.decimalUSDPrice * Currency.current.decimalRate
                payment = Payment(traceID: paymentURL.trace,
                                  token: token,
                                  tokenAmount: amount,
                                  fiatMoneyAmount: fiatMoneyAmount,
                                  memo: paymentURL.memo)
            }
            
            payment.checkPreconditions(
                transferTo: destination,
                reference: paymentURL.reference,
                on: homeContainer
            ) { reason in
                switch reason {
                case .userCancelled:
                    hud.hide()
                case .description(let message):
                    hud.set(style: .error, text: message)
                    hud.scheduleAutoHidden()
                }
            } onSuccess: { (operation, issues) in
                hud.hide()
                let redirection = source.isExternal ? paymentURL.redirection : nil
                let preview = TransferPreviewViewController(issues: issues,
                                                            operation: operation,
                                                            amountDisplay: .byToken,
                                                            redirection: redirection)
                preview.manipulateNavigationStackOnFinished = false
                homeContainer.present(preview, animated: true)
            }
        }
    }
    
    private static func checkMultisig(_ multisig: MultisigURL) {
        guard let homeContainer = UIApplication.homeContainerViewController else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        SafeAPI.multisigs(id: multisig.id, queue: .global()) { result in
            switch result {
            case .success(let response):
                let sendersHash = response.sendersHash
                let receiver = response.receivers.first(where: { $0.membersHash != sendersHash })
                ?? response.receivers.first(where: { $0.membersHash == sendersHash })
                guard let receiver, !receiver.members.isEmpty else {
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                        hud.scheduleAutoHidden()
                    }
                    return
                }
                guard let token = syncToken(assetID: response.assetID, hud: hud) else {
                    return
                }
                guard let senders = syncUsersInOrder(userIDs: response.senders, hud: hud) else {
                    return
                }
                guard let receiverMembers = syncUsers(userIds: receiver.members, hud: hud) else {
                    return
                }
                guard
                    let amount = Decimal(string: response.amount, locale: .enUSPOSIX),
                    let index = response.senders.firstIndex(of: myUserId)
                else {
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                        hud.scheduleAutoHidden()
                    }
                    return
                }
                let state: MultisigPreviewViewController.State
                if response.signers.count >= response.sendersThreshold {
                    state = .paid
                } else if multisig.action == .sign && response.signers.contains(myUserId) {
                    state = .signed
                } else if multisig.action == .unlock && response.signers.isEmpty {
                    state = .unlocked
                } else {
                    state = .pending
                }
                DispatchQueue.main.async {
                    hud.hide()
                    let preview = MultisigPreviewViewController(requestID: response.requestID,
                                                                token: token,
                                                                amount: amount,
                                                                sendersThreshold: response.sendersThreshold,
                                                                senders: senders,
                                                                receiversThreshold: receiver.threshold,
                                                                receivers: receiverMembers,
                                                                rawTransaction: response.rawTransaction,
                                                                viewKeys: response.views.joined(separator: ","),
                                                                action: multisig.action,
                                                                index: index,
                                                                state: state)
                    homeContainer.present(preview, animated: true)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        }
    }
    
    private static func checkCode(_ code: CodeURL, from source: Source, clearNavigationStack: Bool) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        SafeAPI.scheme(uuid: code.uuid) { result in
            switch result {
            case .success(let scheme):
                hud.hide()
                _ = UrlWindow.checkUrl(url: scheme.target, from: source, clearNavigationStack: clearNavigationStack)
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
    }
    
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
    
    private static func checkTIP(_ tip: TIPURL, from source: Source) {
        guard let homeContainer = UIApplication.homeContainerViewController else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: homeContainer.view)
        switch tip {
        case let .sign(requestID, chain, action, raw):
            switch chain {
            case .solana:
                switch action {
                case .signRawTransaction:
                    guard let transaction = Solana.Transaction(string: raw, encoding: .base64URL) else {
                        hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                        hud.scheduleAutoHidden()
                        return
                    }
                    guard let address: String = PropertiesDAO.shared.unsafeValue(forKey: .solanaAddress) else {
                        hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                        hud.hide()
                        return
                    }
                    DispatchQueue.global().async {
                        do {
                            let operation = try SolanaTransferWithCustomRespondingOperation(
                                transaction: transaction,
                                fromAddress: address,
                                chain: .solana
                            ) { signature in
                                guard let requestID, case let .conversation(composer) = source else {
                                    return
                                }
                                let response = [
                                    "request_id": requestID,
                                    "signature": signature,
                                ]
                                let jsonData = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
                                if let jsonData, let json = String(data: jsonData, encoding: .utf8) {
                                    await MainActor.run {
                                        composer.unwrapped?.sendMessage(type: .SIGNAL_TEXT, value: json)
                                    }
                                }
                            }
                            DispatchQueue.main.async {
                                hud.hide()
                                let transfer = Web3TransferViewController(operation: operation, proposer: nil)
                                Web3PopupCoordinator.enqueue(popup: .request(transfer))
                            }
                        } catch {
                            DispatchQueue.main.async {
                                hud.set(style: .error, text: error.localizedDescription)
                                hud.scheduleAutoHidden()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private static func syncToken(assetID: String, hud: Hud) -> TokenItem? {
        var token: TokenItem
        if let localToken = TokenDAO.shared.tokenItem(assetID: assetID) {
            token = localToken
        } else {
            switch SafeAPI.assets(id: assetID) {
            case let .success(remoteToken):
                TokenDAO.shared.save(token: remoteToken)
                token = TokenItem(token: remoteToken, balance: "0", isHidden: false, chain: nil)
            case let .failure(error):
                Logger.general.error(category: "UrlWindow", message: "No token: \(assetID) from remote, error: \(error)")
                let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.asset_not_found())
                DispatchQueue.main.async {
                    hud.set(style: .error, text: text)
                    hud.scheduleAutoHidden()
                }
                return nil
            }
        }
        if token.chain == nil {
            let chain: Chain
            if let localChain = ChainDAO.shared.chain(chainId: token.chainID) {
                chain = localChain
            } else {
                switch NetworkAPI.chain(id: token.chainID) {
                case .success(let remoteChain):
                    ChainDAO.shared.save([remoteChain])
                    chain = remoteChain
                case .failure(let error):
                    Logger.general.error(category: "UrlWindow", message: "No chain: \(token.chainID) from remote, error: \(error)")
                    let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.asset_not_found())
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: text)
                        hud.scheduleAutoHidden()
                    }
                    return nil
                }
            }
            return TokenItem(token: token, balance: token.balance, isHidden: token.isHidden, chain: chain)
        } else {
            return token
        }
    }
    
    private static func syncInscriptionOutput(inscriptionHash: String, hud: Hud) -> (Output, InscriptionItem)? {
        guard let inscriptionOutput = InscriptionDAO.shared.inscriptionOutput(inscriptionHash: inscriptionHash) else {
            Logger.general.error(category: "UrlWindow", message: "Missing output transferring inscription: \(inscriptionHash)")
            DispatchQueue.main.async {
                hud.set(style: .error, text: R.string.localizable.not_found())
                hud.scheduleAutoHidden()
            }
            return nil
        }
        if let item = inscriptionOutput.inscription {
            return (inscriptionOutput.output, item)
        }
        
        func report(error: MixinAPIError) {
            Logger.general.error(category: "UrlWindow", message: "Sync Inscription Failed, hash: \(inscriptionHash), error: \(error)")
            DispatchQueue.main.async {
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
        
        switch InscriptionAPI.inscription(inscriptionHash: inscriptionHash) {
        case let .success(inscription):
            InscriptionDAO.shared.save(inscription: inscription)
            let collection: InscriptionCollection
            if let c = InscriptionDAO.shared.collection(hash: inscription.collectionHash) {
                collection = c
            } else {
                switch InscriptionAPI.collection(collectionHash: inscription.collectionHash) {
                case let .success(c):
                    InscriptionDAO.shared.save(collection: c)
                    collection = c
                case let .failure(error):
                    report(error: error)
                    return nil
                }
            }
            let item = InscriptionItem(collection: collection, inscription: inscription)
            return (inscriptionOutput.output, item)
        case let .failure(error):
            report(error: error)
            return nil
        }
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
        if let chainId = asset?.chainId {
            if let chain = ChainDAO.shared.chain(chainId: chainId) {
                asset?.chain = chain
            } else if case let .success(chain) = AssetAPI.chain(chainId: chainId) {
                ChainDAO.shared.save([chain])
                asset?.chain = chain
            } else {
                return nil
            }
        } else {
            return nil
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
    
    private static func syncUsersInOrder(userIDs ids: [String], hud: Hud) -> [UserItem]? {
        guard let syncedItems = syncUsers(userIds: ids, hud: hud) else {
            return nil
        }
        let items = ids.compactMap { id in
            syncedItems.first(where: { $0.userId == id })
        }
        if items.count == ids.count {
            return items
        } else {
            DispatchQueue.main.async {
                hud.set(style: .error, text: R.string.localizable.user_not_found())
                hud.scheduleAutoHidden()
            }
            return nil
        }
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
            
            let action: PayWindow.PinAction
            if receiverUsers.isEmpty {
                DispatchQueue.main.async {
                    hud.set(style: .error, text: R.string.localizable.invalid_payment_link())
                    hud.scheduleAutoHidden()
                }
                return
            } else if receiverUsers.count == 1 && payment.threshold == 1 {
                action = .transfer(trackId: payment.traceId, user: receiverUsers[0], fromWeb: true, returnTo: nil)
            } else {
                action = .payment(payment: payment, receivers: receiverUsers)
            }
            DispatchQueue.main.async {
                hud.hide()
                PayWindow.instance().render(asset: asset, action: action, amount: payment.amount, memo: payment.memo, error: error).presentPopupControllerAnimated()
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
