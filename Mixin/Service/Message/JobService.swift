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
            if JobService.shared.isFirstRestore {
                JobService.shared.isFirstRestore = false

                JobService.shared.checkConversations()
                JobService.shared.restoreUploadJobs()
            }
            JobService.shared.restoreDownloadJobs()
        }
    }

    private func checkConversations() {
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
        let jobs = JobDAO.shared.nextJobs(category: .Task, action: .UPLOAD_ATTACHMENT)
        for (jobId, messageId) in jobs {
            guard let message = MessageDAO.shared.getMessage(messageId: messageId) else {
                JobDAO.shared.removeJob(jobId: jobId)
                continue
            }
            if message.category.hasSuffix("_IMAGE") {
                UploaderQueue.shared.addJob(job: ImageUploadJob(message: message, jobId: jobId))
            } else if message.category.hasSuffix("_DATA") {
                UploaderQueue.shared.addJob(job: FileUploadJob(message: message, jobId: jobId))
            } else if message.category.hasSuffix("_VIDEO") {
                UploaderQueue.shared.addJob(job: VideoUploadJob(message: message, jobId: jobId))
            } else if message.category.hasSuffix("_AUDIO") {
                UploaderQueue.shared.addJob(job: AudioUploadJob(message: message, jobId: jobId))
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
        let jobs = JobDAO.shared.nextJobs(category: .Task, action: .DOWNLOAD_ATTACHMENT, limit: limit)

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
            } else if message.category.hasSuffix("_IMAGE") {
                downloadJob = AttachmentDownloadJob(message: message, jobId: jobId)
            } else {
                JobDAO.shared.removeJob(jobId: jobId)
                continue
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
