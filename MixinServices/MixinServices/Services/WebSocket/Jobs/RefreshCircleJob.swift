import Foundation

class RefreshCircleJob: AsynchronousJob {

    private let circleId: String

    public init(circleId: String) {
        self.circleId = circleId
    }

    override func getJobId() -> String {
        return "refresh-circle-\(circleId)"
    }

    override func execute() -> Bool {
        CircleAPI.shared.circle(id: circleId, completion: { (result) in
            switch result {
            case let .success(circle):
                DispatchQueue.global().async {
                    guard !MixinService.isStopProcessMessages else {
                        return
                    }
                    CircleDAO.shared.insertOrReplace(circle: circle)
                }
            case .failure:
                break
            }
            self.finishJob()
        })
        return true
    }

}
