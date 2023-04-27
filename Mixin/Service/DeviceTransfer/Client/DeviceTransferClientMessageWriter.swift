import Foundation
import MixinServices

class DeviceTransferClientMessageWriter {
    
    private struct TypeWrapper: Decodable {
        let type: DeviceTransferMessageType
    }
    
    weak var client: DeviceTransferClient?
    
    private let decoder = JSONDecoder.default
    
    init(client: DeviceTransferClient) {
        self.client = client
    }
    
    func take(_ messageData: Data) {
        do {
            let wrapper = try decoder.decode(TypeWrapper.self, from: messageData)
            switch wrapper.type {
            case .conversation:
                let conversation = try decoder.decode(DeviceTransferData<DeviceTransferConversation>.self, from: messageData).data
                ConversationDAO.shared.save(conversation: conversation.toConversation(from: client?.connectionCommand?.platform))
            case .participant:
                let participant = try decoder.decode(DeviceTransferData<DeviceTransferParticipant>.self, from: messageData).data
                ParticipantDAO.shared.save(participant: participant.toParticipant())
            case .user:
                let user = try decoder.decode(DeviceTransferData<DeviceTransferUser>.self, from: messageData).data
                UserDAO.shared.save(user: user.toUser())
            case .app:
                let app = try decoder.decode(DeviceTransferData<DeviceTransferApp>.self, from: messageData).data
                AppDAO.shared.save(app: app.toApp())
            case .asset:
                let asset = try decoder.decode(DeviceTransferData<DeviceTransferAsset>.self, from: messageData).data
                AssetDAO.shared.save(asset: asset.toAsset())
            case .snapshot:
                let snapshot = try decoder.decode(DeviceTransferData<DeviceTransferSnapshot>.self, from: messageData).data
                SnapshotDAO.shared.save(snapshot: snapshot.toSnapshot())
            case .sticker:
                let sticker = try decoder.decode(DeviceTransferData<DeviceTransferSticker>.self, from: messageData).data
                StickerDAO.shared.save(sticker: sticker.toSticker())
            case .pinMessage:
                let pinMessage = try decoder.decode(DeviceTransferData<DeviceTransferPinMessage>.self, from: messageData).data
                PinMessageDAO.shared.save(pinMessage: pinMessage.toPinMessage())
            case .transcriptMessage:
                let transcriptMessage = try decoder.decode(DeviceTransferData<DeviceTransferTranscriptMessage>.self, from: messageData).data
                TranscriptMessageDAO.shared.save(transcriptMessage: transcriptMessage.toTranscriptMessage())
            case .message:
                let message = try decoder.decode(DeviceTransferData<DeviceTransferMessage>.self, from: messageData).data
                if let category = MessageCategory(rawValue: message.category), category != .UNKNOWN {
                    MessageDAO.shared.save(message: message.toMessage())
                }
            case .messageMention:
                if let messageMention = try decoder.decode(DeviceTransferData<DeviceTransferMessageMention>.self, from: messageData).data.toMessageMention() {
                    MessageMentionDAO.shared.save(messageMention: messageMention)
                }
            case .expiredMessage:
                let expiredMessage = try decoder.decode(DeviceTransferData<DeviceTransferExpiredMessage>.self, from: messageData).data
                ExpiredMessageDAO.shared.save(expiredMessage: expiredMessage.toExpiredMessage())
            case .unknown:
                Logger.general.info(category: "DeviceTransferClientMessageWriter", message: "unknown message: \(String(data: messageData, encoding: .utf8) ?? "")")
            }
        } catch {
            if let content = String(data: messageData, encoding: .utf8) {
                Logger.general.info(category: "DeviceTransferClientMessageWriter", message: "\(error) \(content)")
            }
        }
    }
    
}
