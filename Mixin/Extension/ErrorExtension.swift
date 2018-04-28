import Foundation

extension Error {

    var errorCode: Int {
        return (self as NSError).code
    }

    func toJobError() -> JobError {
        switch errorCode {
        case 400..<500:
            return JobError.clientError(code: errorCode)
        case 500..<600:
            return JobError.serverError(code: errorCode)
        default:
            return JobError.networkError
        }
    }
}
