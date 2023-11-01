import Foundation
import UIKit
import AudioToolbox

extension UIDevice {

    static let isJailbreak: Bool = {
        #if DEBUG
        return false
        #else
        if FileManager.default.fileExists(atPath: "/Applications/Cydia.app") ||
            FileManager.default.fileExists(atPath: "/Library/MobileSubstrate/MobileSubstrate.dylib") ||
            FileManager.default.fileExists(atPath: "/bin/bash") ||
            FileManager.default.fileExists(atPath: "/usr/bin/sshd") ||
            FileManager.default.fileExists(atPath: "/usr/sbin/sshd") ||
            FileManager.default.fileExists(atPath: "/etc/apt") ||
            FileManager.default.fileExists(atPath: "/private/var/lib/apt") ||
            FileManager.default.fileExists(atPath: "/private/var/lib/cydia") ||
            FileManager.default.fileExists(atPath: "/private/var/stash") ||
            UIApplication.shared.canOpenURL(URL(string:"cydia://package/com.example.package")!) {
            return true
        }

        let stringToWrite = "Jailbreak Test"
        do
        {
            try stringToWrite.write(toFile:"/private/JailbreakTest.txt", atomically: true, encoding:.utf8)
            try? FileManager.default.removeItem(atPath: "/private/JailbreakTest.txt")
            return true
        } catch {
            return false
        }
        #endif
    }()
    
}

extension UIDevice {
    
    private static var paymentSuccessSoundID: SystemSoundID = 0
    
    func playInputDelete() {
        AudioServicesPlaySystemSound(1155)
    }
    
    func playPaymentSuccess() {
        assert(Thread.isMainThread)
        if Self.paymentSuccessSoundID == 0, let url = R.file.payment_successCaf.url() {
            AudioServicesCreateSystemSoundID(url as CFURL, &Self.paymentSuccessSoundID)
        }
        if Self.paymentSuccessSoundID != 0 {
            AudioServicesPlaySystemSound(Self.paymentSuccessSoundID)
        }
    }
    
}
