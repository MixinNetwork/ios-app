import Foundation
import MixinServices

public struct DeviceTransferCommand: Codable {
        
    public let deviceId: String
    public let platform: String
    public let action: Action
    public let version: Int
    public let ip: String?
    public let port: Int?
    public let secretKey: String?
    public let code: Int?
    public let total: Int?
    public let userId: String?
    public let progress: Double?
    
    public enum Action: String, Codable {
        case pull
        case push
        case start
        case connect
        case finish
        case progress
        case cancel
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case platform
        case action
        case version
        case ip
        case port
        case secretKey = "secret_key"
        case code
        case total
        case userId = "user_id"
        case progress
    }
    
    public init(
        deviceId: String = Device.current.id,
        platform: String = "iOS",
        action: Action,
        version: Int = AppGroupUserDefaults.User.deviceTransferVersion,
        ip: String? = nil,
        port: Int? = nil,
        secretKey: String? = nil,
        code: Int? = nil,
        total: Int? = nil,
        userId: String? = nil,
        progress: Double? = 0
    ) {
        self.deviceId = deviceId
        self.platform = platform
        self.action = action
        self.version = version
        self.ip = ip
        self.port = port
        self.secretKey = secretKey
        self.code = code
        self.total = total
        self.userId = userId
        self.progress = progress
    }
    
}
