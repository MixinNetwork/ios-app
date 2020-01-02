import Foundation

public class Localized {
    
    public static let DATE_FORMAT_DAY = localized("date_format_day", arguments: ["hh:mm a"])
    public static let DATE_FORMAT_MONTH = localized("date_format_month", arguments: ["E, d MMM"])
    public static let DATE_FORMAT_DATE = localized("date_format_date", arguments: ["MMM dd, yyyy"])
    public static let DATE_FORMAT_TRANSATION = localized("date_format_transation", arguments: ["MMM dd, HH:mm"])
    
    public static let NOTIFICATION_MUTE = localized("notification_mute")
    public static let NOTIFICATION_REPLY = localized("notification_reply")
    public static let NOTIFICATION_CONTENT_GENERAL = localized("notification_content_general")
    public static let NOTIFICATION_CONTENT_PHOTO = localized("notification_content_photo")
    public static let NOTIFICATION_CONTENT_TRANSFER = localized("notification_content_transfer")
    public static let NOTIFICATION_CONTENT_FILE = localized("notification_content_file")
    public static let NOTIFICATION_CONTENT_STICKER = localized("notification_content_sticker")
    public static let NOTIFICATION_CONTENT_CONTACT = localized("notification_content_contact")
    public static let NOTIFICATION_CONTENT_DEPOSIT = localized("notification_content_deposit")
    public static let NOTIFICATION_CONTENT_FEE = localized("notification_content_fee")
    public static let NOTIFICATION_CONTENT_WITHDRAWAL = localized("notification_content_withdrawal")
    public static let NOTIFICATION_CONTENT_REBATE = localized("notification_content_rebate")
    public static let NOTIFICATION_CONTENT_VIDEO = localized("notification_content_video")
    public static let NOTIFICATION_CONTENT_AUDIO = localized("notification_content_audio")
    public static let NOTIFICATION_CONTENT_LIVE = localized("notification_content_live")
    public static let NOTIFICATION_CONTENT_VOICE_CALL = localized("notification_content_voice_call")
    public static let ALERT_KEY_CONTACT_AUDIO_CALL_CANCELLED_MESSAGE = localized("alert_key_contact_audio_call_cancelled_message")
    
    public static let ALERT_KEY_CONTACT_MESSAGE = localized("alert_key_contact_message")
    public static let ALERT_KEY_CONTACT_TEXT_MESSAGE = localized("alert_key_contact_text_message")
    public static let ALERT_KEY_CONTACT_IMAGE_MESSAGE = localized("alert_key_contact_image_message")
    public static let ALERT_KEY_CONTACT_VIDEO_MESSAGE = localized("alert_key_contact_video_message")
    public static let ALERT_KEY_CONTACT_TRANSFER_MESSAGE = localized("alert_key_contact_transfer_message")
    public static let ALERT_KEY_CONTACT_DATA_MESSAGE = localized("alert_key_contact_data_message")
    public static let ALERT_KEY_CONTACT_STICKER_MESSAGE = localized("alert_key_contact_sticker_message")
    public static let ALERT_KEY_CONTACT_CONTACT_MESSAGE = localized("alert_key_contact_contact_message")
    public static let ALERT_KEY_CONTACT_AUDIO_MESSAGE = localized("alert_key_contact_audio_message")
    public static let ALERT_KEY_CONTACT_AUDIO_CALL_MESSAGE = localized("alert_key_contact_audio_call_message")
    public static let ALERT_KEY_CONTACT_LIVE_MESSAGE = localized("alert_key_contact_live_message")
    
    public static func ALERT_KEY_GROUP_MESSAGE(fullname: String) -> String {
        return localized("alert_key_group_message", arguments: [fullname])
    }
    public static func ALERT_KEY_GROUP_TEXT_MESSAGE(fullname: String) -> String {
        return localized("alert_key_group_text_message", arguments: [fullname])
    }
    public static func ALERT_KEY_GROUP_IMAGE_MESSAGE(fullname: String) -> String {
        return localized("alert_key_group_image_message", arguments: [fullname])
    }
    public static func ALERT_KEY_GROUP_VIDEO_MESSAGE(fullname: String) -> String {
        return localized("alert_key_group_video_message", arguments: [fullname])
    }
    public static func ALERT_KEY_GROUP_DATA_MESSAGE(fullname: String) -> String {
        return localized("alert_key_group_data_message", arguments: [fullname])
    }
    public static func ALERT_KEY_GROUP_STICKER_MESSAGE(fullname: String) -> String {
        return localized("alert_key_group_sticker_message", arguments: [fullname])
    }
    public static func ALERT_KEY_GROUP_CONTACT_MESSAGE(fullname: String) -> String {
        return localized("alert_key_group_contact_message", arguments: [fullname])
    }
    public static func ALERT_KEY_GROUP_AUDIO_MESSAGE(fullname: String) -> String {
        return localized("alert_key_group_audio_message", arguments: [fullname])
    }
    public static func ALERT_KEY_GROUP_LIVE_MESSAGE(fullname: String) -> String {
        return localized("alert_key_group_live_message", arguments: [fullname])
    }
    
    public static let TOAST_API_ERROR_CONNECTION_TIMEOUT = localized("toast_api_error_connection_timeout")
    public static let TOAST_OPERATION_FAILED = localized("toast_operation_failed")
    
    public static let WALLET_TOUCH_ID = localized("wallet_touch_id")
    public static let WALLET_FACE_ID = localized("wallet_face_id")
    public static func WALLET_STORE_ENCRYPTED_PIN(biometricType: String) -> String {
        return localized("wallet_store_encrypted_pin", arguments: [biometricType])
    }
    
    public static let CHAT_TIME_TODAY = localized("chat_time_today")
    public static let CHAT_MESSAGE_YOU = localized("chat_message_you")
    public static func CHAT_MESSAGE_CREATED(fullName: String) -> String {
        return localized("chat_message_created", arguments: [fullName])
    }
    public static func CHAT_MESSAGE_REMOVED(adminFullName: String, participantFullName: String) -> String {
        return localized("chat_message_removed", arguments: [adminFullName, participantFullName])
    }
    public static func CHAT_MESSAGE_ADDED(inviterFullName: String, inviteeFullName: String) -> String {
        return localized("chat_message_added", arguments: [inviterFullName, inviteeFullName])
    }
    public static func CHAT_MESSAGE_LEFT(fullName: String) -> String {
        return localized("chat_message_left", arguments: [fullName])
    }
    public static func CHAT_MESSAGE_JOINED(fullName: String) -> String {
        return localized("chat_message_joined", arguments: [fullName])
    }
    public static func CHAT_MESSAGE_ADMIN(fullName: String) -> String {
        return localized("chat_message_admin", arguments: [fullName])
    }
    
}

extension Localized {
    
    private static let bundle: Bundle = {
        let frameworkBundle = Bundle(for: Localized.self)
        let localizationBundleUrl = frameworkBundle.url(forResource: "MixinServicesLocalization", withExtension: "bundle")!
        return Bundle(url: localizationBundleUrl)!
    }()
    
    private static func localized(_ key: String) -> String {
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    private static func localized(_ key: String, arguments: [String]) -> String {
        let format = NSLocalizedString(key, bundle: bundle, comment: "")
        return String(format: format, arguments: arguments)
    }
    
}
