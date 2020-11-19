import Foundation

public enum MixinServicesError: Error {
    
    private static var basicUserInfo: [String: Any] {
        var userInfo = reporter.basicUserInfo
        userInfo["didLogin"] = LoginManager.shared.isLoggedIn
        userInfo["isAppExtension"] = isAppExtension
        return userInfo
    }
    
    case saveIdentity
    case encryptGroupMessageData(SignalError)
    case extractEncryptedPin
    case duplicatedMessage
    case nilMimeType([String: Any])
    case duplicatedJob
    case sendMessage([String: Any])
    case refreshOneTimePreKeys(error: SignalError, identityCount: Int)
    case initInputStream(url: URL, isEncrypted: Bool, fileAttributes: [FileAttributeKey: Any]?, error: Error?)
    case initDecryptingOutputStream
    case initOutputStream
    case decryptMessage([String: Any])
    case badMessageData(id: String, status: String, from: String)
    case logout(isAsyncRequest: Bool)
    case badParticipantSession
    case websocketError(errType: String, errMessage: String, errCode: Int)
    case messageTooBig(gzipSize: Int, category: String, conversationId: String)
    case gzipFailed
    case emptyResponse
    case badKrakenBlazeMessage
    case missingConversationId
    case invalidScalingContextParameter([String: Any])
    
}

extension MixinServicesError: CustomNSError {
    
    public static var errorDomain: String {
        return "MixinServicesError"
    }
    
    public var errorCode: Int {
        switch self {
        case .saveIdentity:
            return 0
        case .encryptGroupMessageData:
            return 1
        case .extractEncryptedPin:
            return 2
        case .duplicatedMessage:
            return 3
        case .nilMimeType:
            return 4
        case .duplicatedJob:
            return 5
        case .sendMessage:
            return 6
        case .refreshOneTimePreKeys:
            return 7
        case .initInputStream:
            return 8
        case .initDecryptingOutputStream:
            return 10
        case .initOutputStream:
            return 11
        case .decryptMessage:
            return 12
        case .badMessageData:
            return 13
        case .logout:
            return 14
        case .badParticipantSession:
            return 15
        case .websocketError:
            return 16
        case .messageTooBig:
            return 17
        case .gzipFailed:
            return 18
        case .emptyResponse:
            return 21
        case .badKrakenBlazeMessage:
            return 22
        case .missingConversationId:
            return 23
        case .invalidScalingContextParameter:
            return 24
        }
    }
    
    public var errorUserInfo: [String : Any] {
        var userInfo: [String : Any]
        switch self {
        case let .encryptGroupMessageData(error):
            userInfo = Self.basicUserInfo
            userInfo["signalCode"] = error.rawValue
        case let .nilMimeType(info):
            userInfo = info
        case .duplicatedJob:
            userInfo = Self.basicUserInfo
        case let .sendMessage(info):
            userInfo = info
        case let .refreshOneTimePreKeys(error, identityCount):
            userInfo = Self.basicUserInfo
            userInfo["signalCode"] = error.rawValue
            userInfo["identityCount"] = identityCount
        case let .initInputStream(url, isEncrypted, attrs, error):
            if let attrs = attrs {
                userInfo = [:]
                for attr in attrs {
                    userInfo[attr.key.rawValue] = attr.value
                }
            } else {
                userInfo = ["error": error]
            }
            userInfo["url_string"] = url.absoluteString
            userInfo["encrypted"] = isEncrypted
        case let .decryptMessage(info):
            userInfo = Self.basicUserInfo
            for (key, value) in info {
                userInfo[key] = value
            }
        case let .badMessageData(id, status, from):
            userInfo = ["messageId": id,
                        "status" : status,
                        "from": from]
        case let .logout(isAsyncRequest):
            return ["isAsyncRequest": isAsyncRequest]
        case let .websocketError(errType, errMessage, errCode):
            userInfo = Self.basicUserInfo
            userInfo["errType"] = errType
            userInfo["errMessage"] = errMessage
            userInfo["errCode"] = "\(errCode)"
        case let .messageTooBig(gzipSize, category, conversationId):
            userInfo = Self.basicUserInfo
            userInfo["conversationId"] = conversationId
            userInfo["category"] = category
            userInfo["size"] = "\(gzipSize / 1024)kb"
        case let .invalidScalingContextParameter(info):
            userInfo = info
        default:
            userInfo = [:]
        }
        return userInfo
    }
    
}
