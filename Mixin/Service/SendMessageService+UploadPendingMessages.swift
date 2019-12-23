import Foundation

extension SendMessageService {
    
    @objc func uploadAnyPendingMessages() {
        let messages = MessageDAO.shared.getPendingMessages()
        for message in messages {
            guard message.shouldUpload() else {
                continue
            }
            if message.category.hasSuffix("_IMAGE") {
                UploaderQueue.shared.addJob(job: ImageUploadJob(message: message))
            } else if message.category.hasSuffix("_DATA") {
                UploaderQueue.shared.addJob(job: FileUploadJob(message: message))
            } else if message.category.hasSuffix("_VIDEO") {
                UploaderQueue.shared.addJob(job: VideoUploadJob(message: message))
            } else if message.category.hasSuffix("_AUDIO") {
                UploaderQueue.shared.addJob(job: AudioUploadJob(message: message))
            }
        }
    }
    
}
