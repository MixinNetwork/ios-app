import Foundation
import UIKit
import FirebaseMLVision

enum MuteInterval {
    static let none: Int64 = 0
    static let eightHours: Int64 = 8 * 60 * 60
    static let oneWeek: Int64 = 7 * 24 * 60 * 60
    static let oneYear: Int64 = 365 * 24 * 60 * 60
}

enum StatusBarHeight {
    static let normal: CGFloat = 20
    static let inCall: CGFloat = 40
}

let iTunesAppUrlRegex = try? NSRegularExpression(pattern: "^https://itunes\\.apple\\.com/.*app.*id[0-9]", options: .caseInsensitive)

let qrCodeDetector: VisionBarcodeDetector = {
    let options = VisionBarcodeDetectorOptions(formats: .qrCode)
    return Vision.vision().barcodeDetector(options: options)
}()

let bytesPerMegaByte: UInt = 1024 * 1024

enum PeriodicPinVerificationInterval {
    static let min: TimeInterval = 60 * 10
    static let max: TimeInterval = 60 * 60 * 24
}

var backupUrl: URL? {
    FileManager.default.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent(myIdentityNumber)
        .appendingPathComponent("Backup")
}

let backupDatabaseName = "mixin.db"
