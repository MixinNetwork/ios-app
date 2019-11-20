import Foundation
import UIKit

class SignalProtocol {

    let DEFAULT_DEVICE_ID: Int32 = 1
    static let shared = SignalProtocol()
    private var store: SignalStore

    init() {
        store = try! SignalStore(
            identityKeyStore: MixinIdentityKeyStore(),
            preKeyStore: MixinPreKeyStore(),
            sessionStore: MixinSessionStore(),
            signedPreKeyStore: MixinSignedPreKeyStore(),
            senderKeyStore: MixinSenderKeyStore())
    }

    func initSignal() {
        let localRegistrationId = try! Signal.generateRegistrationId()
        let identityKeyPair = try! Signal.generateIdentityKeyPair()
        
        AppGroupUserDefaults.Signal.registrationId = localRegistrationId
        AppGroupUserDefaults.Signal.privateKey = identityKeyPair.privateKey
        AppGroupUserDefaults.Signal.publicKey = identityKeyPair.publicKey
    }

    func getRegistrationId() -> UInt32 {
        return AppGroupUserDefaults.Signal.registrationId
    }

    func clearSenderKey(groupId: String, senderId: String) {
        let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID))
        store.senderKeyStore!.removeSenderKey(senderKeyName: senderKeyName)
    }

    func isExistSenderKey(groupId: String, senderId: String) -> Bool {
        let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID))
        let data = store.senderKeyStore!.loadSenderKey(for: senderKeyName)
        return data != nil
    }

    func containsUserSession(recipientId: String) -> Bool {
        return SessionDAO.shared.getSessions(address: recipientId).count > 0
    }

    func containsSession(recipient: String, deviceId: Int32 = SignalProtocol.shared.DEFAULT_DEVICE_ID) -> Bool {
        let address = SignalAddress(name: recipient, deviceId: deviceId)
        return store.sessionStore.containsSession(for: address)
    }

    func deleteSession(userId: String) {
        SessionDAO.shared.delete(address: userId)
    }

    func processSession(userId: String, key: SignalKey) throws {
        let address = SignalAddress(name: userId, deviceId: key.deviceId)
        let sessionBuilder = SessionBuilder(for: address, in: store)
        let preKeyBundle = SessionPreKeyBundle(registrationId: key.registrationId,
                                                     deviceId: key.deviceId,
                                                     preKeyId: key.preKey.key_id,
                                                     preKey: key.getPreKeyPublic(),
                                                     signedPreKeyId: UInt32(key.signedPreKey.key_id),
                                                     signedPreKey: key.getSignedPreKeyPublic(),
                                                     signature: key.getSignedSignature(),
                                                     identityKey: key.getIdentityPublic())
        try sessionBuilder.process(preKeyBundle: preKeyBundle)
    }

    func getSenderKeyDistribution(groupId: String, senderId: String) throws -> CiphertextMessage {
        let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID))
        let senderKeyData = store.senderKeyStore!.loadSenderKey(for: senderKeyName)
        let builder = GroupSessionBuilder(in: store)
        if (senderKeyData == nil) {
            return try builder.createSession(for: senderKeyName)
        } else {
            return try builder.getDistributionMessage(for: senderKeyName)
        }
    }

    func encryptSenderKey(conversationId: String, recipientId: String, sessionId: String?) throws -> (String, Bool) {
        let deviceId = SignalProtocol.convertSessionIdToDeviceId(sessionId)
        let senderKeyDistributionMessage = try getSenderKeyDistribution(groupId: conversationId, senderId: AccountAPI.shared.accountUserId)
        do {
            let cipherMessage = try encryptSession(content: senderKeyDistributionMessage.message, destination: recipientId, deviceId: deviceId)
            let compose = ComposeMessageData(keyType: cipherMessage.type.rawValue, cipher: cipherMessage.message, resendMessageId: nil)
            return (encodeMessageData(data: compose), false)
        } catch {
            if let err = error as? SignalError, err == SignalError.untrustedIdentity {
                let remoteAddress = SignalAddress(name: recipientId, deviceId: deviceId)
                IdentityDAO.shared.deleteIdentity(address: remoteAddress.name)
                _ = store.sessionStore.deleteSession(for: remoteAddress)
                return ("", true)
            }
            throw error
        }
    }

    func encryptSessionMessageData(recipientId: String, content: String, resendMessageId: String? = nil, sessionId: String? = nil) throws -> String {
        let cipher = try encryptSession(content: content.data(using: .utf8)!, destination: recipientId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        let data = encodeMessageData(data: ComposeMessageData(keyType: cipher.type.rawValue, cipher: cipher.message, resendMessageId: resendMessageId))
        return data
    }

    func encryptGroupMessageData(conversationId: String, senderId: String, content: String) throws -> String {
        let senderKeyName = SignalSenderKeyName(groupId: conversationId, sender: SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID))
        let groupCipher = GroupCipher(for: senderKeyName, in: store)
        var cipher = Data()
        do {
            cipher = try groupCipher.encrypt(content.data(using: .utf8)!).message
        } catch SignalError.noSession {
            // Do nothing
        } catch let error as SignalError {
            Reporter.report(error: MixinServicesError.encryptGroupMessageData(error))
        } catch {
            Reporter.report(error: error)
        }
        let data = encodeMessageData(data: ComposeMessageData(keyType: CiphertextMessage.MessageType.senderKey.rawValue, cipher: cipher, resendMessageId: nil))
        return data
    }

    func decrypt(groupId: String, senderId: String, keyType: UInt8, cipherText: Data, category: String, sessionId: String?, callback: @escaping DecryptionCallback) throws {
        let sourceAddress = SignalAddress(name: senderId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        let sessionCipher = SessionCipher(for: sourceAddress, in: store)
        if category == MessageCategory.SIGNAL_KEY.rawValue {
            if keyType == CiphertextMessage.MessageType.preKey.rawValue {
                _ = try sessionCipher.decrypt(message: CiphertextMessage(type: .preKey, message: cipherText), callback: { (plain) in
                    SignalProtocol.shared.processGroupSession(groupId: groupId, sender: sourceAddress, data: plain)
                    callback(plain)
                })

            } else if keyType == CiphertextMessage.MessageType.signal.rawValue {
                _ = try sessionCipher.decrypt(message: CiphertextMessage(type: .signal, message: cipherText), callback: { (plain) in
                    SignalProtocol.shared.processGroupSession(groupId: groupId, sender: sourceAddress, data: plain)
                    callback(plain)
                })
            }
        } else {
            if keyType == CiphertextMessage.MessageType.preKey.rawValue {
                _ = try sessionCipher.decrypt(message: CiphertextMessage(type: .preKey, message: cipherText), callback: callback)
            } else if keyType == CiphertextMessage.MessageType.signal.rawValue {
                _ = try sessionCipher.decrypt(message: CiphertextMessage(type: .signal, message: cipherText), callback: callback)
            } else if keyType == CiphertextMessage.MessageType.senderKey.rawValue {
                let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: sourceAddress)
                let groupCipher = GroupCipher(for: senderKeyName, in: store)
                _ = try groupCipher.decrypt(CiphertextMessage(type: .senderKey, message: cipherText), callback: callback)
            }
        }
    }

    private func encryptSession(content: Data, destination: String, deviceId: Int32) throws -> CiphertextMessage {
        let address = SignalAddress(name: destination, deviceId: deviceId)
        let sessionCipher = SessionCipher(for: address, in: store)
        return try sessionCipher.encrypt(content)
    }

    func processGroupSession(groupId: String, sender: SignalAddress, data: Data) {
        let senderKeyDM = CiphertextMessage(type: .distribution, message: data)
        let builder = GroupSessionBuilder(in: store)
        let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: sender)
        try! builder.process(senderKeyDistributionMessage: senderKeyDM, from: senderKeyName)
    }

    struct ComposeMessageData {
        var keyType: UInt8
        var cipher: Data
        var resendMessageId: String?
    }

    func encodeMessageData(data: ComposeMessageData) -> String {
        if data.resendMessageId == nil {
            let header: [UInt8] = [3, data.keyType, 0, 0, 0, 0, 0, 0]
            let headerData = Data(header)
            let cipherText = headerData + data.cipher
            return cipherText.base64EncodedString()
        } else {
            let header = [3, data.keyType, 1, 0, 0, 0, 0, 0]
            let messageId = data.resendMessageId!
            let cipherText = Data(header) + messageId.data(using: .utf8)! + data.cipher
            return cipherText.base64EncodedString()
        }
    }

    func decodeMessageData(encoded: String) -> ComposeMessageData {
        let cipherText = Data(base64Encoded: encoded)!
        let header = cipherText.subdata(in: 0..<8)
        _ = header.bytes[0]
        let dataType = header.bytes[1]
        let isResendMessage = header.bytes[2]
        if (isResendMessage == 1) {
            let messageId = cipherText.subdata(in: 8..<44)
            let data = cipherText.subdata(in: 44..<cipherText.count)
            return ComposeMessageData(keyType: dataType, cipher: data, resendMessageId: messageId.toString())
        } else {
            let data = cipherText.subdata(in: 8..<cipherText.count)
            return ComposeMessageData(keyType: dataType, cipher: data, resendMessageId: nil)
        }
    }

}

extension SignalProtocol {

    static func convertSessionIdToDeviceId(_ sessionId: String?) -> Int32 {
        guard let sessionId = sessionId, !sessionId.isEmpty else {
            return 1
        }
        return sessionId.toUUID().hashCode()
    }

}
