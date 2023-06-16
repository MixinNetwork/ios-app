import Foundation

public struct DeviceTransferCommand {
    
    public static let localVersion = 2
    
    public struct PushContext {
        
        public let hostname: String
        public let port: UInt16
        public let code: UInt16
        public let key: DeviceTransferKey
        public let userID: String?
        
        public init(hostname: String, port: UInt16, code: UInt16, key: DeviceTransferKey, userID: String?) {
            self.hostname = hostname
            self.port = port
            self.code = code
            self.key = key
            self.userID = userID
        }
        
    }
    
    public enum Action {
        case pull
        case push(PushContext)
        case start(Int64)
        case connect(code: UInt16, userID: String)
        case progress(Float) // `progress` is between 0.0 and 1.0, encoded to / decoded from between 0.0 and 100.0
        case cancel
        case finish
    }
    
    public let version: Int
    public let deviceID: String
    public let platform: DeviceTransferPlatform
    public let action: Action
    
    public init(action: Action) {
        self.version = Self.localVersion
        self.deviceID = Device.current.id
        self.platform = .iOS
        self.action = action
    }
    
}

extension DeviceTransferCommand: CustomStringConvertible {
    
    public var description: String {
        if let jsonData = try? JSONEncoder.default.encode(self), let json = String(data: jsonData, encoding: .utf8) {
            return json
        } else {
            return String(describing: action)
        }
    }
    
}

extension DeviceTransferCommand: Codable {
    
    public enum DecodingError: Error {
        case unknownAction(String)
        case invalidSecretKey
    }
    
    private enum ActionName {
        static let pull = "pull"
        static let push = "push"
        static let start = "start"
        static let connect = "connect"
        static let progress = "progress"
        static let cancel = "cancel"
        static let finish = "finish"
    }
    
    private enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case platform
        case action
        case version
        case hostname = "ip"
        case port
        case secretKey = "secret_key"
        case code
        case total
        case userID = "user_id"
        case progress
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(Int.self, forKey: .version)
        self.deviceID = try container.decode(String.self, forKey: .deviceId)
        self.platform = try container.decode(DeviceTransferPlatform.self, forKey: .platform)
        self.action = try {
            let rawValue = try container.decode(String.self, forKey: .action)
            switch rawValue {
            case ActionName.pull:
                return .pull
            case ActionName.push:
                let secretKeyString = try container.decode(String.self, forKey: .secretKey)
                guard let secretKey = Data(base64Encoded: secretKeyString), let key = DeviceTransferKey(raw: secretKey) else {
                    throw DecodingError.invalidSecretKey
                }
                let hostname = try container.decode(String.self, forKey: .hostname)
                let port = try container.decode(UInt16.self, forKey: .port)
                let code = try container.decode(UInt16.self, forKey: .code)
                let userID = try container.decodeIfPresent(String.self, forKey: .userID)
                let context = PushContext(hostname: hostname,
                                          port: port,
                                          code: code,
                                          key: key,
                                          userID: userID)
                return .push(context)
            case ActionName.start:
                let count = try container.decode(Int64.self, forKey: .total)
                return .start(count)
            case ActionName.connect:
                let code = try container.decode(UInt16.self, forKey: .code)
                let userID = try container.decode(String.self, forKey: .userID)
                return .connect(code: code, userID: userID)
            case ActionName.progress:
                let progress = try container.decode(Float.self, forKey: .progress)
                return .progress(progress / 100)
            case ActionName.cancel:
                return .cancel
            case ActionName.finish:
                return .finish
            default:
                throw DecodingError.unknownAction(rawValue)
            }
        }()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(deviceID, forKey: .deviceId)
        try container.encode(platform, forKey: .platform)
        switch action {
        case .pull:
            try container.encode(ActionName.pull, forKey: .action)
        case let .push(context):
            try container.encode(ActionName.push, forKey: .action)
            try container.encode(context.hostname, forKey: .hostname)
            try container.encode(context.port, forKey: .port)
            try container.encode(context.code, forKey: .code)
            if let userID = context.userID {
                try container.encode(userID, forKey: .userID)
            }
            try container.encode(context.key.raw.base64EncodedString(), forKey: .secretKey)
        case let .start(count):
            try container.encode(ActionName.start, forKey: .action)
            try container.encode(count, forKey: .total)
        case let .connect(code, userID):
            try container.encode(ActionName.connect, forKey: .action)
            try container.encode(code, forKey: .code)
            try container.encode(userID, forKey: .userID)
        case let .progress(progress):
            try container.encode(ActionName.progress, forKey: .action)
            try container.encode(progress * 100, forKey: .progress)
        case .cancel:
            try container.encode(ActionName.cancel, forKey: .action)
        case .finish:
            try container.encode(ActionName.finish, forKey: .action)
        }
    }
    
}
