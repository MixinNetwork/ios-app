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
                ConversationDAO.shared.insert(conversation: conversation.toConversation())
            case .message:
                let message = try decoder.decode(DeviceTransferData<DeviceTransferMessage>.self, from: messageData).data
                MessageDAO.shared.insert(message: message.toMessage())
            case .sticker:
                let sticker = try decoder.decode(DeviceTransferData<DeviceTransferSticker>.self, from: messageData).data
                StickerDAO.shared.inser(sticker: sticker.toSticker())
            case .asset:
                let asset = try decoder.decode(DeviceTransferData<DeviceTransferAsset>.self, from: messageData).data
                AssetDAO.shared.insert(asset: asset.toAsset())
            case .snapshot:
                let snapshot = try decoder.decode(DeviceTransferData<DeviceTransferSnapshot>.self, from: messageData).data
                SnapshotDAO.shared.insert(snapshot: snapshot.toSnapshot())
            case .user:
                let user = try decoder.decode(DeviceTransferData<DeviceTransferUser>.self, from: messageData).data
                UserDAO.shared.insert(user: user.toUser())
            case .pinMessage:
                let pinMessage = try decoder.decode(DeviceTransferData<DeviceTransferPinMessage>.self, from: messageData).data
                PinMessageDAO.shared.inser(pinMessage: pinMessage.toPinMessage())
            case .expiredMessage:
                let expiredMessage = try decoder.decode(DeviceTransferData<DeviceTransferExpiredMessage>.self, from: messageData).data
                ExpiredMessageDAO.shared.insert(expiredMessage: expiredMessage.toExpiredMessage())
            case .transcriptMessage:
                let transcriptMessage = try decoder.decode(DeviceTransferData<DeviceTransferTranscriptMessage>.self, from: messageData).data
                TranscriptMessageDAO.shared.insert(transcriptMessage: transcriptMessage.toTranscriptMessage())
            case .participant:
                let participant = try decoder.decode(DeviceTransferData<DeviceTransferParticipant>.self, from: messageData).data
                ParticipantDAO.shared.insert(participant: participant.toParticipant())
            case .command, .unknown:
                break
            }
        } catch {
            if let content = String(data: messageData, encoding: .utf8) {
                Logger.general.info(category: "DeviceTransferClientMessageWriter", message: "\(error) \(content)")
            }
        }
    }
    
}
