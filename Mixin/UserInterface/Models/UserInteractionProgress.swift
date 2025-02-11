import Foundation

struct UserInteractionProgress {
    
    let currentStep: Int
    let totalStepCount: Int
    
    init(currentStep: Int, totalStepCount: Int) {
        self.currentStep = currentStep
        self.totalStepCount = totalStepCount
    }
    
}

extension UserInteractionProgress: CustomStringConvertible {
    
    var description: String {
        "\(currentStep)/\(totalStepCount)"
    }
    
}
