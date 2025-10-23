import Foundation
import UIKit
import SDWebImage
import MixinServices

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

let iTunesAppUrlRegex = try? NSRegularExpression(pattern: "^https://(itunes|apps)\\.apple\\.com/.*app.*id[0-9]", options: .caseInsensitive)
let appStoreAppID = "1322324266"

let qrCodeDetector: CIDetector? = {
    let context = CIContext()
    let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    return CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: options)
}()

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

let voipTokenRemove = "REMOVE"

let maxTextMessageContentLength = 64 * 1024

let maxNumberOfTranscriptChildren = 99

let minimumTransferAmount: Decimal = 0.000_000_01

let maxGroupMemberCount = 1024

let referralIconImage: UIImage? = {
    let scale = UIScreen.main.scale
    let url = switch UIScreen.main.scale {
    case 2:
        R.file.referral2xJson()!
    default:
        R.file.referral3xJson()!
    }
    guard let data = try? Data(contentsOf: url) else {
        return nil
    }
    return SDAnimatedImage(data: data, scale: UIScreen.main.scale)
}()
