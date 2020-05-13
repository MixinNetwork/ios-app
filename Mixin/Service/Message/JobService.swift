import Foundation
import MixinServices

class JobService {

    static let shared = JobService()

    private var isFirstRestore = true

    private static var canBatchProcessMessages: Bool {
        !isAppExtension &&
        canProcessMessages &&
        !MixinService.isStopProcessMessages &&
        UIApplication.isApplicationActive
    }

    @objc func restoreJobs() {
        DispatchQueue.global().async {
            guard JobService.canBatchProcessMessages else {
                return
            }
            if JobService.shared.isFirstRestore {
                JobService.shared.isFirstRestore = false

                JobService.shared.checkConversations()
                JobService.shared.restoreUploadJobs()
            } else if AppGroupUserDefaults.User.hasRestoreUploadAttachment {
                AppGroupUserDefaults.User.hasRestoreUploadAttachment = false
                JobService.shared.restoreUploadJobs()
            }
            JobService.shared.recoverPendingWebRTCJobs()
            JobService.shared.recoverMediaJobs()
        }
    }

    private func checkConversations() {
        let startConversationIds = ConversationDAO.shared.getStartStatusConversations()
        for conversationId in startConversationIds {
            ConcurrentJobQueue.shared.addJob(job: CreateConversationJob(conversationId: conversationId))
        }

        let participantIds = ParticipantDAO.shared.getSyncParticipantIds()
        if participantIds.count > 0 {
            ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: participantIds, updateParticipantStatus: true))
        }
    }

    func restoreUploadJobs() {
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
            guard JobService.canBatchProcessMessages else {
                return
            }
            JobService.shared.recoverMediaJobs()
        }
    }
    
    private func recoverPendingWebRTCJobs() {
        let jobs = JobDAO.shared.nextBatchJobs(category: .Task, action: .PENDING_WEBRTC, limit: nil)
        for job in jobs {
            defer {
                JobDAO.shared.removeJob(jobId: job.jobId)
            }
            if let data = job.blazeMessageData {
                CallManager.shared.handleIncomingBlazeMessageData(data)
            }
        }
    }

    private func recoverMediaJobs() {
        guard NetworkManager.shared.isReachableOnWiFi else {
            return
        }
        let limit = 5
        let jobs = JobDAO.shared.nextJobs(category: .Task, action: .RECOVER_ATTACHMENT, limit: limit)

        for (jobId, messageId) in jobs {
            guard let message = MessageDAO.shared.getMessage(messageId: messageId) else {
                JobDAO.shared.removeJob(jobId: jobId)
                continue
            }
            let downloadJob: AttachmentDownloadJob
            if message.category.hasSuffix("_VIDEO") {
                downloadJob = VideoDownloadJob(message: message, jobId: jobId, isRecoverAttachment: true)
            } else if message.category.hasSuffix("_DATA") {
                downloadJob = FileDownloadJob(message: message, jobId: jobId, isRecoverAttachment: true)
            } else if message.category.hasSuffix("_AUDIO") {
                downloadJob = AudioDownloadJob(message: message, jobId: jobId, isRecoverAttachment: true)
            } else if message.category.hasSuffix("_IMAGE") {
                downloadJob = AttachmentDownloadJob(message: message, jobId: jobId, isRecoverAttachment: true)
            } else {
                JobDAO.shared.removeJob(jobId: jobId)
                continue
            }
            downloadJob.completionBlock = {
                guard !ConcurrentJobQueue.shared.isExistRecoverAttachment() else {
                    return
                }
                JobService.shared.processDownloadJobs()
            }
            ConcurrentJobQueue.shared.addJob(job: downloadJob)
        }
    }

}
