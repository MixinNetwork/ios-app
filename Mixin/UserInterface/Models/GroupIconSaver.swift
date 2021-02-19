import Foundation
import MixinServices

enum GroupIconSaver {
    
    enum Error: Swift.Error {
        case fileExists(String)
        case unableToCompress
    }
    
    // Returns filename
    static func save(image: UIImage, forGroupWith conversationId: String, participants: [ParticipantUser]) throws -> String {
        let participantIds: [String] = participants.map { (participant) in
            if participant.userAvatarUrl.isEmpty {
                return String(participant.userFullName.prefix(1))
            } else {
                return participant.userAvatarUrl
            }
        }
        let filename = conversationId + "-" + participantIds.joined().md5() + ".jpg"
        let url = AppGroupContainer.groupIconsUrl.appendingPathComponent(filename)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw Error.fileExists(filename)
        }
        if let data = image.jpegData(compressionQuality: JPEGCompressionQuality.medium) {
            try data.write(to: url)
            return filename
        } else {
            throw Error.unableToCompress
        }
    }
    
}
