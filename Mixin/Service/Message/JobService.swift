import Foundation
import MixinServices

class JobService {

    static let shared = JobService()

    private var isFirstRestore = true

    @objc func restoreJobs() {
        DispatchQueue.global().async {
            guard UIApplication.canBatchProcessMessages else {
                return
            }
            JobService.shared.checkConversations()
            JobService.shared.restoreUploadJobs()
        }
    }

    private func checkConversations() {
        guard isFirstRestore else {
            return
        }
        isFirstRestore = false

        let startConversationIds = ConversationDAO.shared.getStartStatusConversations()
        for conversationId in startConversationIds {
            ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: conversationId))
        }

        let problemConversationIds = ConversationDAO.shared.getProblemConversations()
        for conversationId in problemConversationIds {
            ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: conversationId))
        }

        let quitConversationIds = ConversationDAO.shared.getQuitStatusConversations()
        for conversationId in quitConversationIds {
            ConcurrentJobQueue.shared.addJob(job: ExitConversationJob(conversationId: conversationId))
        }

        let participantIds = ParticipantDAO.shared.getSyncParticipantIds()
        if participantIds.count > 0 {
            ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: participantIds, updateParticipantStatus: true))
        }
    }

    private func restoreUploadJobs() {
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

    public func processDownloadJobs() {
        DispatchQueue.global().async {
            guard UIApplication.canBatchProcessMessages else {
                return
            }
            JobService.shared.restoreDownloadJobs()
        }
    }

    private func restoreDownloadJobs() {
        let limit = 5
        let jobs = JobDAO.shared.nextJobs(category: .Task, action: .DOWNLOAD_MEDIA, limit: limit)

        for (idx, (jobId, messageId)) in jobs.enumerated() {
            guard let message = MessageDAO.shared.getMessage(messageId: messageId) else {
                JobDAO.shared.removeJob(jobId: jobId)
                continue
            }
            let downloadJob: AttachmentDownloadJob
            if message.category.hasSuffix("_VIDEO") {
                downloadJob = VideoDownloadJob(message: message, jobId: jobId)
            } else if message.category.hasSuffix("_DATA") {
                downloadJob = FileDownloadJob(message: message, jobId: jobId)
            } else if message.category.hasSuffix("_AUDIO") {
                downloadJob = AudioDownloadJob(message: message, jobId: jobId)
            } else {
                downloadJob = AttachmentDownloadJob(message: message, jobId: jobId)
            }
            if idx == limit - 1 {
                downloadJob.completionBlock = {
                    JobService.shared.processDownloadJobs()
                }
            }
            ConcurrentJobQueue.shared.addJob(job: downloadJob)
        }
    }

}
