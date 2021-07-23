import Foundation

public func LocalizedString(_ key: String, comment: String) -> String {
    let localText = NSLocalizedString(key, comment: "")
    return localText == key ? comment :  localText
}

public class Localized {

    // Common
    public static let DIALOG_BUTTON_OK = LocalizedString("dialog_button_ok", comment: "OK")
    public static let DIALOG_BUTTON_CANCEL = LocalizedString("dialog_button_cancel", comment: "Cancel")
    public static let DIALOG_BUTTON_CHANGE = LocalizedString("dialog_button_change", comment: "Change")
    public static let DIALOG_BUTTON_CONFIRM = LocalizedString("dialog_button_confirm", comment: "Confirm")
    public static let DIALOG_BUTTON_DISABLE = LocalizedString("dialog_button_disable", comment: "Disable")
    public static let DIALOG_BUTTON_NO_REMIND = LocalizedString("dialog_button_no_remind", comment: "Don't remind me again")
    public static let ACTION_NEXT = LocalizedString("action_next", comment: "Next")
    public static let ACTION_REMOVE = LocalizedString("action_remove", comment: "Remove")
    public static let ACTION_CAMERA = LocalizedString("action_camera", comment: "Camera")
    public static let ACTION_DONE = LocalizedString("action_done", comment: "Done")
    public static let ACTION_CHOOSE_PHOTO = LocalizedString("action_choose_photo", comment: "Choose Photo")
    public static let ACTION_SAVE = LocalizedString("action_save", comment: "Save")
    public static let ACTION_REFRESH = LocalizedString("action_refresh", comment: "Refresh")
    public static let ACTION_SELECT = LocalizedString("action_select", comment: "Select")
    public static let ACTION_CLEAR = LocalizedString("action_clear", comment: "Clear")
    public static let ACTION_SEND = LocalizedString("action_send", comment: "Send")
    public static let ACTION_SEND_TO = LocalizedString("action_send_to", comment: "Send To")
    public static let ACTION_SHARE_TO = LocalizedString("action_share_to", comment: "Share To")
    public static let ACTION_HIDE = LocalizedString("action_hide", comment: "Hide")
    public static let ACTION_SHOW = LocalizedString("action_show", comment: "Show")
    public static let ACTION_DELETE_ME = LocalizedString("action_delete_me", comment: "Delete for Me")
    public static let ACTION_DELETE_EVERYONE = LocalizedString("action_delete_everyone", comment: "Delete for Everyone")
    public static let MENU_DELETE = LocalizedString("menu_delete", comment: "Delete")
    public static let MENU_EDIT = LocalizedString("menu_edit", comment: "Edit")
    public static let ALL_PHOTOS = LocalizedString("all_photos", comment: "All Photos")
    public static let NO_RESULT = LocalizedString("no_result", comment: "No result")
    
    public static let CONNECTION_HINT_CONNECTING = LocalizedString("connection_hint_connecting", comment: "Connecting")
    public static func CONNECTION_HINT_PROGRESS(_ progress: Int) -> String {
        return String(format: LocalizedString("connection_hint_progress", comment: "Syncing messages %@%%"), "\(progress)")
    }
    
    // Landing - PhoneNumberVerification
    public static func LANDING_PHONE_VERIFICATION_TITLE(_ type: String) -> String {
        return String(format: LocalizedString("landing_phone_verification_title", comment: "please verify your phone number to %@"), type)
    }
    public static let LANDING_PHONE_VERIFICATION_LINK_PRIVACY = LocalizedString("landing_phone_verification_link_privacy", comment: "Privacy Policy")
    public static func LANDING_PHONE_VERIFICATION_HINT_PRIVACY(privacy: String) -> String {
        return String(format: LocalizedString("landing_phone_verification_hint_privacy", comment: "We will never display your phone number publicly, read our %@ to learn more."), privacy)
    }
    public static let LANDING_PHONE_VERIFICATION_BUTTON_SWITCH_TO_LOGIN = LocalizedString("landing_phone_verification_button_switch_to_login", comment: "Have an account? Log in")
    public static let LANDING_PHONE_VERIFICATION_BUTTON_SWITCH_TO_SIGNUP = LocalizedString("landing_phone_verification_button_switch_to_signup", comment: "No account yet? Sign up")

    public static func LANDING_PHONE_DIALOG_TITLE(phoneNumber: String) -> String {
        return String(format: LocalizedString("landing_phone_dialog_title", comment: "We will send a verification code to %@"), phoneNumber)
    }
    public static let LANDING_PHONE_DIALOG_MESSAGE = LocalizedString("landing_phone_dialog_message", comment: "Please enter the 4 digit verification code in next screen to verify your phone number.")
    public static let LANDING_PHONE_DIALOG_BUTTON_SEND_SMS = LocalizedString("landing_phone_dialog_button_send_sms", comment: "Send via SMS")
    public static let LANDING_PHONE_DIALOG_BUTTON_CANCEL = LocalizedString("landing_phone_dialog_button_cancel", comment: "Cancel")

    // Error
    public static let PERMISSION_DENIED_CAMERA = LocalizedString("permission_denied_camera", comment: "Mixin doesn't have permission to use your camera. Please tap Setting to open system settings.")
    public static let PERMISSION_DENIED_PHOTO_LIBRARY = LocalizedString("permission_denied_photo_library", comment: "Mixin doesn't have permission to use your photo library. Please tap Setting to open system settings.")
    public static let PERMISSION_DENIED_MICROPHONE = LocalizedString("permission_denied_microphone", comment: "Mixin doesn't have permission to use your microphone. Please tap Setting to open system settings.")
    public static let TOAST_COPIED = LocalizedString("toast_copied", comment: "Copied")
    public static let TOAST_ADDED = LocalizedString("toast_added", comment: "Added")
    public static let TOAST_SAVED = LocalizedString("toast_saved", comment: "Saved")
    public static let TOAST_LOGINED = LocalizedString("toast_logined", comment: "Logined")
    public static let TOAST_AUTHORIZED = LocalizedString("toast_authorized", comment: "Authorized")
    public static let TOAST_CHANGED = LocalizedString("toast_changed", comment: "Changed")
    public static let SCREEN_CAPTURED_PIN_LEAKING_HINT = LocalizedString("screen_captured_pin_leaking_hint", comment: "Screen recorder detected, PIN may be recorded.")
    public static func BIOMETRY_SUGGESTION(biometricType: String) -> String {
        return String(format: LocalizedString("biometry_suggestion", comment: " %@ is suggested."), biometricType)
    }
    
    // Login
    public static func NAVIGATION_TITLE_ENTER_VERIFICATION_CODE(mobileNumber: String) -> String {
        return String(format: LocalizedString("navigation_title_enter_verification_code", comment: "Enter the 4-digit code sent to you at %@"), mobileNumber)
    }
    public static func NAVIGATION_TITLE_ENTER_EMERGENCY_CONTACT_VERIFICATION_CODE(id: String) -> String {
        return String(format: LocalizedString("navigation_title_enter_emergency_contact_verification_code", comment: "Enter the 4-digit code sent to Mixin ID %@"), id)
    }
    public static let TEXT_INTRO = LocalizedString("text_intro", comment: "A messenger that transfers all crypto currencies with end to end encryption. Tap \"%@\" to accept %@ and %@")
    public static let TEXT_CONFIRM_SEND_CODE = LocalizedString("text_confirm_send_code", comment: "Please confirm the phone number %@")
    public static let TEXT_INVALID_VERIFICATION_CODE = LocalizedString("text_invalid_verification_code", comment: "The code is incorrect.")
    public static let BUTTON_TITLE_AGREE_AND_CONTINUE = LocalizedString("button_title_agree_and_continue", comment: "Agree & Continue")
    public static let BUTTON_TITLE_TERMS_OF_SERVICE = LocalizedString("button_title_terms_of_service", comment: "Terms of Service")
    public static let BUTTON_TITLE_PRIVACY_POLICY = LocalizedString("button_title_privacy_policy", comment: "Privacy Policy")
    public static let BUTTON_TITLE_RESEND_CODE = LocalizedString("button_title_resend_code", comment: "Resend code")
    public static let BUTTON_TITLE_RESEND_CODE_PENDING = LocalizedString("button_title_resend_code_pending", comment: "Resend code in %@")
    public static let HEADER_TITLE_CURRENT_SELECTED = LocalizedString("header_title_current_selected", comment: "Current Selected")
    public static let HEADER_TITLE_CURRENT_LOCATION = LocalizedString("header_title_current_location", comment: "Current Location")
    
    // Contacts
    public static let CONTACT_TITLE_CHANGE_NAME = LocalizedString("contact_title_change_name", comment: "Change name")
    public static let CONTACT_NEW_GROUP_TITLE = LocalizedString("contact_new_group_title", comment: "New Group Chat")
    public static let CONTACT_NEW_GROUP_SUMMARY = LocalizedString("contact_new_group_summary", comment: "Create a group chat up to 256 people")
    public static let CONTACT_ADD_TITLE = LocalizedString("contact_add_title", comment: "Add Contact")
    public static let CONTACT_ADD_SUMMARY = LocalizedString("contact_add_summary", comment: "Add people by Mixin ID or phone number")
    public static let CONTACT_QR_CODE_TITLE = LocalizedString("contact_qr_code_title", comment: "Mixin QR Code")
    public static let CONTACT_QR_CODE_SUMMARY = LocalizedString("contact_qr_code_summary", comment: "Scan a friend's Mixin QR Code")
    public static let CONTACT_INVITE_TITLE = LocalizedString("contact_invite_title", comment: "Invite People")
    public static func contact_invite_summary(code: String) -> String {
        return String(format: LocalizedString("contact_invite_summary", comment: "My invitation code %@"), code)
    }
    public static let CONTACT_INVITE = LocalizedString("contact_invite", comment: "Hey, I'm using Mixin Messenger to chat. Download it here: https://mixin.one/messenger")
    public static let CONTACT_PROFILE_TITLE = LocalizedString("contact_profile_title", comment: "My Profile")
    public static let CONTACT_TITLE = LocalizedString("contact_title", comment: "Contacts")
    public static let CONTACT_PHONE_CONTACTS = LocalizedString("contact_phone_contacts", comment: "Mobile Contacts")
    public static let CONTACT_PHONE_CONTACT_SUMMARY = LocalizedString("contact_phone_contact_summary", comment: "Mixin needs access to your contacts to help you connect with other people on Mixin.")
    public static func CONTACT_MY_IDENTITY_NUMBER(id: String) -> String {
        return String(format: LocalizedString("contact_my_identity_number", comment: "My Mixin ID: %@"), id)
    }
    public static func CONTACT_IDENTITY_NUMBER(identityNumber: String) -> String {
        return String(format: LocalizedString("contact_identity_number", comment: "Mixin ID: %@"), identityNumber)
    }
    public static func CONTACT_MOBILE(mobile: String) -> String {
        return String(format: LocalizedString("contact_mobile", comment: "Mobile: %@"), mobile)
    }
    public static let CONTACT_ERROR_COMPOSE_AVATAR = LocalizedString("contact_error_compose_avatar", comment: "Failed to compose avatar. Try another picture instead.")
    public static let BUTTON_TITLE_SEARCH = LocalizedString("button_title_search", comment: "Search")
    public static let PLACEHOLDER_NEW_NAME = LocalizedString("placeholder_new_name", comment: "new name")
    public static let NAVIGATION_TITLE_ADD_PEOPLE = LocalizedString("navigation_title_add_people", comment: "Add people")
    public static let CONTACT_AVATAR_PICKING_FAIL = LocalizedString("contact_avatar_picking_fail", comment: "Failed to change your profile photo")
    public static let CONTACT_CHANGE_NAME_FAIL = LocalizedString("contact_change_name_fail", comment: "Failed to change your name")
    public static let CONTACT_MY_QR_CODE = LocalizedString("contact_my_qr_code", comment: "My QR Code")
    public static let CONTACT_RECEIVE_MONEY = LocalizedString("contact_receive_money", comment: "Receive Money")
    public static let PLACEHOLDER_MIXIN_ID_OR_PHONE = LocalizedString("placeholder_mixin_id_or_phone", comment: "Mixin ID, Phone number")
    
    // Home
    public static let HOME_TITLE = LocalizedString("home_title", comment: "Chats")

    // Chat
    public static let CHAT_MESSAGE_MENU_REPLY = LocalizedString("chat_message_menu_reply", comment: "Reply")
    public static let CHAT_MESSAGE_MENU_FORWARD = LocalizedString("chat_message_menu_forward", comment: "Forward")
    public static let CHAT_MESSAGE_MENU_COPY = LocalizedString("chat_message_menu_copy", comment: "Copy")
    public static let CHAT_MESSAGE_OPEN_URL = LocalizedString("chat_message_open_url", comment: "Open URL")
    public static let CHAT_MESSAGE_ADD = LocalizedString("chat_message_sticker", comment: "Add to Stickers")
    public static let CHAT_MESSAGE_CALL_CANCELLED = LocalizedString("chat_message_call_cancelled", comment: "Cancelled")
    public static let CHAT_MESSAGE_CALL_REMOTE_CANCELLED = LocalizedString("chat_message_call_remote_cancelled", comment: "Cancelled by caller")
    public static let CHAT_MESSAGE_CALL_DECLINED = LocalizedString("chat_message_call_declined", comment: "Declined")
    public static let CHAT_MESSAGE_CALL_REMOTE_DECLINED = LocalizedString("chat_message_call_remote_declined", comment: "Declined")
    public static let CHAT_MESSAGE_CALL_BUSY = LocalizedString("chat_message_call_busy", comment: "Line busy")
    public static let CHAT_MESSAGE_CALL_REMOTE_BUSY = LocalizedString("chat_message_call_remote_busy", comment: "Line busy")
    public static let CHAT_MESSAGE_CALL_FAILED = LocalizedString("chat_message_call_failed", comment: "Failed")
    public static func CHAT_MESSAGE_CALL_DURATION(duration: String) -> String {
        return String(format: LocalizedString("chat_message_call_duration", comment: "Duration %@"), duration)
    }
    public static func CHAT_MESSAGE_CHANGED_TITLE(fullName: String, title: String) -> String {
        return String(format: LocalizedString("chat_message_changed_title", comment: "%@ changed the subject to %@"), fullName, title)
    }
    public static let CHAT_CELL_TITLE_ENCRYPTION = LocalizedString("chat_cell_title_encryption", comment: "Messages to this conversation are encrypted end-to-end, click for more information")
    public static let CHAT_CELL_TITLE_UNKNOWN_CATEGORY = LocalizedString("chat_cell_title_unknown_category", comment: "This type of message is not supported, please upgrade Mixin to the latest version.")
    public static let CHAT_FORWARD_TITLE = LocalizedString("chat_forward_title", comment: "Forward")
    public static let CHAT_FORWARD_CHATS = LocalizedString("chat_forward_chats", comment: "CHATS")
    public static let CHAT_FORWARD_CONTACTS = LocalizedString("chat_forward_contacts", comment: "CONTACTS")
    public static func CHAT_DECRYPTION_FAILED_HINT(username: String) -> String {
        return String(format: LocalizedString("chat_decryption_failed_hint", comment: "Waiting for %@ to get online and establish an encrypted session. "), username)
    }
    public static let CHAT_SEND_PHOTO_FAILED = LocalizedString("chat_send_photo_failed", comment: "Failed to send photo")
    public static let CHAT_SEND_FILE_FAILED = LocalizedString("chat_send_file_failed", comment: "Failed to send file")
    public static let CHAT_SEND_VIDEO_FAILED = LocalizedString("chat_send_video_failed", comment: "Failed to send video")
    public static let CHAT_SEND_AUDIO_FAILED = LocalizedString("chat_send_audio_failed", comment: "Failed to send audio")
    public static let CHAT_MENU_CAMERA = LocalizedString("chat_menu_camera", comment: "Camera")
    public static let CHAT_MENU_PHOTO = LocalizedString("chat_menu_photo", comment: "Photo & Video")
    public static let CHAT_MENU_FILE = LocalizedString("chat_menu_file", comment: "File")
    public static let CHAT_MENU_TRANSFER = LocalizedString("chat_menu_transfer", comment: "Transfer")
    public static let CHAT_MENU_CONTACT = LocalizedString("chat_menu_contact", comment: "Contact")
    public static let CHAT_MENU_CALL = LocalizedString("chat_menu_call", comment: "Call")
    public static let CHAT_MENU_DEVELOPER = LocalizedString("chat_menu_developer", comment: "Developer")
    public static let CHAT_PHOTO_SAVE = LocalizedString("chat_photo_save", comment: "Save to Camera Roll")
    public static let CHAT_FILE_EXPIRED = LocalizedString("chat_file_expired", comment: "Expired")
    public static let CHAT_QUOTE_TYPE_STICKER = LocalizedString("chat_quote_type_sticker", comment: "Sticker")
    public static let CHAT_QUOTE_TYPE_PHOTO = LocalizedString("chat_quote_type_photo", comment: "Photo")
    public static let CHAT_QUOTE_TYPE_VIDEO = LocalizedString("chat_quote_type_video", comment: "Video")
    public static let CHAT_RESTORE_SUBTITLE = LocalizedString("chat_restore_subtitle", comment: "You will not be able to restore later if you decline to restore now. Media files will continue restore in background after messages is restored.")
    
    // Sticker
    public static let STICKER_MANAGER_TITLE = LocalizedString("sticker_manager_title", comment: "My Stickers")
    public static let STICKER_ADD_TITLE = LocalizedString("sticker_add_title", comment: "Add Sticker")
    public static let STICKER_REMOVE_TITLE = LocalizedString("sticker_remove_title", comment: "Delete Stickers")
    public static let STICKER_ADD_FAILED = LocalizedString("sticker_add_failed", comment: "Failed to add sticker")
    public static let STICKER_REMOVE_FAILED = LocalizedString("sticker_remove_failed", comment: "Failed to delete stickers")
    public static let STICKER_ADD_REQUIRED = LocalizedString("sticker_add_required", comment: "Requires stickers file size larger than 1KB and less than 1MB, aspect ratio between 16:9 and 9:16.")
    public static func STICKER_COUNT(count: Int) -> String {
        return String(format: LocalizedString("sticker_count", comment: "%@ Stickers"), "\(count)")
    }
    
    // Camera
    public static let CAMERA_SAVE_PHOTO_SUCCESS = LocalizedString("camera_save_photo_success", comment: "Photo saved.")
    public static let CAMERA_SAVE_PHOTO_FAILED = LocalizedString("camera_save_photo_failed", comment: "Unable to save photo.")
    public static let CAMERA_SEND_TO_TITLE = LocalizedString("camera_send_to_title", comment: "Send To")
    public static let CAMERA_SAVE_VIDEO_SUCCESS = LocalizedString("camera_save_video_success", comment: "Video saved.")
    public static let CAMERA_SAVE_VIDEO_FAILED = LocalizedString("camera_save_video_failed", comment: "Unable to save video.")
    public static let IMAGE_PICKER_TITLE_ALBUMS = LocalizedString("image_picker_title_albums", comment: "Albums")

    // Group
    public static let GROUP_NAVIGATION_TITLE_ADD_MEMBER = LocalizedString("group_navigation_title_add_member", comment: "Add Participants")
    public static let GROUP_NAVIGATION_TITLE_NEW_GROUP = LocalizedString("group_navigation_title_new_group", comment: "New Group")
    public static let GROUP_NAVIGATION_TITLE_GROUP_INFO = LocalizedString("group_navigation_title_group_info", comment: "Group Info")
    public static let GROUP_NAVIGATION_TITLE_INVITE_LINK = LocalizedString("group_navigation_title_invite_link", comment: "Invite to Group via Link")
    public static let GROUP_NAVIGATION_TITLE_ANNOUNCEMENT = LocalizedString("group_navigation_title_announcement", comment: "Group Description")
    public static func GROUP_SECTION_TITLE_MEMBERS(count: Int) -> String {
        let number = count > 0 ? "\(count) " : ""
        return number + LocalizedString("group_section_title_members", comment: "PARTICIPANTS")
    }
    public static let GROUP_BUTTON_TITLE_CREATE = LocalizedString("group_button_title_create", comment: "Create")
    public static let GROUP_BUTTON_TITLE_VIEW = LocalizedString("group_button_title_view", comment: "View Group")
    public static let GROUP_BUTTON_TITLE_JOIN = LocalizedString("group_button_title_join", comment: "Join Group")
    public static let GROUP_CREATE_GROUP_FAIL = LocalizedString("group_create_group_fail", comment: "Failed to create a group, please try again later")
    public static let GROUP_CLEAR_SUCCESS = LocalizedString("group_clear_success", comment: "Cleared")
    public static func GROUP_REMOVE_CONFIRM(fullName: String, groupName: String) -> String {
        return String(format: LocalizedString("group_remove_confirm", comment: "Remove %@ from the '%@' group?"), fullName, groupName)
    }
    public static let GROUP_REMOVE_BUTTON = LocalizedString("group_remove_button", comment: "Remove from Group")
    public static let GROUP_ROLE_ADMIN = LocalizedString("group_role_admin", comment: "Admin")
    public static let GROUP_PARTICIPANT_MENU_INFO = LocalizedString("group_participant_menu_info", comment: "Info")
    public static let GROUP_PARTICIPANT_MENU_SEND = LocalizedString("group_participant_menu_send", comment: "Send Message")
    public static let GROUP_PARTICIPANT_MENU_REMOVE = LocalizedString("group_participant_menu_remove", comment: "Remove from Group")
    public static let GROUP_JOIN_FAIL_TITLE = LocalizedString("group_join_fail_title", comment: "Couldn't Join Group")
    public static let GROUP_JOIN_FAIL_SUMMARY = LocalizedString("group_join_fail_summary", comment: "This invite link doesn't match any Mixin groups.")
    public static let CODE_RECOGNITION_FAIL_TITLE = LocalizedString("code_recognition_fail_title", comment: "Unrecognized codes")
    public static let CODE_RECOGNITION_FAIL_SUMMARY = LocalizedString("code_recognition_fail_summary", comment: "This codes doesn't match any Mixin groups or users.")
    public static let GROUP_LINK_CHECKING = LocalizedString("group_link_checking", comment: "Checking invite link")
    public static let GROUP_REMOVE_TITLE = LocalizedString("group_remove_title", comment: "you were removed from the group")
    public static let GROUP_MENU_ANNOUNCEMENT = LocalizedString("group_menu_announcement", comment: "Edit Group Description")
    public static let GROUP_MENU_PARTICIPANTS = LocalizedString("group_menu_participants", comment: "Participants")
    public static func GROUP_TITLE_MEMBERS(count: String) -> String {
        return String(format: LocalizedString("group_title_members", comment: "%@ Participants"), count)
    }
    public static let GROUP_BUTTON_TITLE_RESET_LINK = LocalizedString("group_button_title_reset_link", comment: "Reset Link")
    
    // QRCode
    public static let MYQRCODE_TITLE = LocalizedString("myqrcode_title", comment: "My QR Code")
    public static let MYQRCODE_PROMPT = LocalizedString("myqrcode_prompt", comment: "Scan the QR Code to add me on Mixin")
    public static let NOT_MIXIN_QR_CODE = LocalizedString("not_mixin_qr_code", comment: "Not Mixin QR Code")
    public static let GROUP_QR_CODE = LocalizedString("group_qr_code", comment: "Group QR Code")
    public static let GROUP_QR_CODE_PROMPT = LocalizedString("group_qr_code_prompt", comment: "Scan the QR Code to join this group")
    public static let AUTH_SUCCESS = LocalizedString("auth_success", comment: "Scan the QR Code to join this group")
    public static let AUTH_PERMISSION_PROFILE = LocalizedString("auth_permission_profile", comment: "Public profile (required)")
    public static let AUTH_PERMISSION_PHONE = LocalizedString("auth_permission_phone", comment: "Phone number")
    public static let AUTH_PERMISSION_ASSETS = LocalizedString("auth_permission_assets", comment: "Assets balance")
    public static let AUTH_PERMISSION_APPS_READ = LocalizedString("auth_permission_apps_read", comment: "Read apps")
    public static let AUTH_PERMISSION_APPS_READ_DESCRIPTION = LocalizedString("auth_permission_apps_read_description", comment: "access your apps list")
    public static let AUTH_PERMISSION_APPS_WRITE = LocalizedString("auth_permission_apps_write", comment: "Manage apps")
    public static let AUTH_PERMISSION_APPS_WRITE_DESCRIPTION = LocalizedString("auth_permission_apps_write_description", comment: "mange all your apps")
    public static let AUTH_PERMISSION_CONTACTS_READ = LocalizedString("auth_permission_contacts_read", comment: "Read contacts")
    public static let AUTH_PERMISSION_CONTACTS_READ_DESCRIPTION = LocalizedString("auth_permission_contacts_read_description", comment: "access your contacts list")
    public static func AUTH_SUCCESS(name: String) -> String {
        return String(format: LocalizedString("auth_success", comment: "Successfully log in to %@"), name)
    }
    public static func AUTH_PROFILE_DESCRIPTION(fullName: String, phone: String) -> String {
        return String(format: LocalizedString("auth_profile_description", comment: "%@, %@, profile photo"), fullName, phone)
    }
    public static let AUTH_ASSETS_MORE = LocalizedString("auth_assets_more", comment: " and more")
    public static let SCAN_QR_CODE = LocalizedString("scan_qr_code", comment: "Scan QR Code")
    public static let TRANSFER_QRCODE_PROMPT = LocalizedString("transfer_qrcode_prompt", comment: "Scan the QR Code to transfer me on Mixin")
    public static let TRANSFER_BALANCE = LocalizedString("transfer_balance", comment: "BALANCE")

    // Profile
    public static let PROFILE_TITLE = LocalizedString("profile_title", comment: "Info")
    public static let PROFILE_OPEN_BOT = LocalizedString("profile_open_bot", comment: "Open App")
    public static func PROFILE_MIXIN_ID(id: String) -> String {
        return String(format: LocalizedString("profile_mixin_id", comment: "Mixin ID: %@"), id)
    }
    public static func PROFILE_REPUTATION_SCORE(reputation: Int) -> String {
        return String(format: LocalizedString("profile_reputation_score", comment: "Reputation Score: %@"), String(reputation))
    }
    public static let PROFILE_SHARE_CARD = LocalizedString("profile_share_card", comment: "Share Contact")
    public static let PROFILE_TRANSACTIONS = LocalizedString("profile_transactions", comment: "Transactions")
    public static let PROFILE_BLOCK = LocalizedString("profile_block", comment: "Block")
    public static let PROFILE_UNBLOCK = LocalizedString("profile_unblock", comment: "Unblock")
    public static let PROFILE_FULL_NAME = LocalizedString("profile_full_name", comment: "Name")
    public static let PROFILE_EDIT_NAME = LocalizedString("profile_edit_name", comment: "Edit Name")
    public static let PROFILE_ADD_CONTACT_FAIL = LocalizedString("profile_add_contact_fail", comment: "Failed to add contact")
    public static let PROFILE_REMOVE_CONTACT_FAIL = LocalizedString("profile_remove_contact_fail", comment: "Failed to remove contact")
    public static let PROFILE_MUTE_DURATION_8H = LocalizedString("profile_mute_duration_8h", comment: "8 hours")
    public static let PROFILE_MUTE_DURATION_1WEEK = LocalizedString("profile_mute_duration_1week", comment: "1 week")
    public static let PROFILE_MUTE_DURATION_1YEAR = LocalizedString("profile_mute_duration_1year", comment: "1 year")
    public static let PROFILE_MUTE = LocalizedString("profile_mute", comment: "Mute")
    public static let PROFILE_CHANGE_NUMBER = LocalizedString("profile_change_number", comment: "Change Number")
    public static let PROFILE_CHANGE_NUMBER_CONFIRMATION = LocalizedString("profile_change_number_confirmation", comment: "Do you want to change the phone number?")
    public static let PROFILE_CHANGE_NUMBER_SUCCEEDED = LocalizedString("profile_change_number_succeeded", comment: "Successfully changed phone number")
    public static let PROFILE_TOAST_UNMUTED = LocalizedString("profile_toast_unmuted", comment: "Unmuted")
    public static func PROFILE_TOAST_MUTED(muteUntil: String) -> String {
        return String(format: LocalizedString("profile_toast_muted", comment: "Muted until %@"), muteUntil)
    }

    // Home
    public static let SECTION_TITLE_CONTACTS = LocalizedString("section_title_contacts", comment: "CONTACTS")
    public static let SECTION_TITLE_MESSAGES = LocalizedString("section_title_messages", comment: "MESSAGES")
    public static let SECTION_TITLE_ASSETS = LocalizedString("section_title_assets", comment: "ASSETS")
    public static let HOME_CELL_ACTION_PIN = LocalizedString("home_cell_action_pin", comment: "Pin")
    public static let HOME_CELL_ACTION_UNPIN = LocalizedString("home_cell_action_unpin", comment: "Unpin")

    // Wallet
    public static let WALLET_TITLE = LocalizedString("wallet_title", comment: "Wallet")
    public static let WALLET_TITLE_ADD_ASSET = LocalizedString("wallet_title_add_asset", comment: "Add asset")
    public static let WALLET_ALREADY_HAD_THE_ASSET = LocalizedString("wallet_already_had_the_asset", comment: "Already had")
    public static let WALLET_TRANSFER_OUT = LocalizedString("wallet_transfer_out", comment: "Transfer Out")
    public static let WALLET_SYMBOL_OTHER = LocalizedString("wallet_symbol_other", comment: "Other")
    public static let WALLET_TRANSFER_BALANCE_INSUFFICIENT = LocalizedString("wallet_transfer_balance_insufficient", comment: "Insufficient balance")
    public static let WALLET_CHANGE_PASSWORD = LocalizedString("wallet_change_password", comment: "Change PIN")
    public static let WALLET_PASSWORD_VERIFY_TITLE = LocalizedString("wallet_password_verify_title", comment: "Old PIN")
    public static let WALLET_CHANGE_PASSWORD_SUCCESS = LocalizedString("wallet_change_password_success", comment: "Change PIN successfully")
    public static let WALLET_SET_PASSWORD_SUCCESS = LocalizedString("wallet_set_password_success", comment: "Set PIN successfully")
    public static let WALLET_DEPOSIT = LocalizedString("wallet_deposit", comment: "Deposit")
    public static func WALLET_DEPOSIT_CONFIRMATIONS(confirmations: Int) -> String {
        return String(format: LocalizedString("wallet_deposit_confirmations", comment: "Deposit will arrive after at least %@ block confirmations."), "\(confirmations)")
    }
    public static let WALLET_NO_TRANSACTION = LocalizedString("wallet_no_transaction", comment: "No transaction")
    public static let WALLET_ADDRESS = LocalizedString("wallet_address", comment: "Address")
    public static let WALLET_MENU_SHOW_HIDDEN_ASSETS = LocalizedString("wallet_menu_show_hidden_assets", comment: "Hidden assets")
    public static let WALLET_MENU_SHOW_ASSET = LocalizedString("wallet_menu_show_asset", comment: "Show asset")
    public static let WALLET_MENU_HIDE_ASSET = LocalizedString("wallet_menu_hide_asset", comment: "Hide asset")
    public static let WALLET_HIDE_ASSET_EMPTY = LocalizedString("wallet_hide_asset_empty", comment: "No hidden assets")
    public static func WALLET_HINT_TRANSACTION_FEE(feeRepresentation: String, name: String) -> String {
        return String(format: LocalizedString("wallet_hint_transaction_fee", comment: "A transaction fee of %@ is required for withdrawing %@."), feeRepresentation, name)
    }
    public static func WALLET_WITHDRAWAL_ASSET(assetName: String) -> String {
        return String(format: LocalizedString("wallet_withdrawal_asset", comment: "%@ Withdrawal"), assetName)
    }
    public static let WALLET_WITHDRAWAL_PAY_PASSWORD = LocalizedString("wallet_withdrawal_pay_password", comment: "Withdrawal with PIN")
    public static func WALLET_WITHDRAWAL_RESERVE(reserveRepresentation: String, name: String) -> String {
        return String(format: LocalizedString("wallet_withdrawal_reserve", comment: " %@ has a minimum %@ reserve requirement."), name, reserveRepresentation)
    }
    public static let WALLET_NO_PRICE = LocalizedString("wallet_no_price", comment: "N/A")
    public static let WALLET_PIN_CREATE_TITLE = LocalizedString("wallet_pin_create_title", comment: "Set a 6 digit PIN to create your first digital wallet")
    public static let WALLET_PIN_CONFIRM_TITLE = LocalizedString("wallet_pin_confirm_title", comment: "Please confirm the 6 digit PIN and remember it")
    public static let WALLET_PIN_CONFIRM_SUBTITLE = LocalizedString("wallet_pin_confirm_subtitle", comment: "If lost, there is no way to recover your wallet.")
    public static let WALLET_PIN_CONFIRM_AGAIN_TITLE = LocalizedString("wallet_pin_confirm_again_title", comment: "Please confirm your 6 digit PIN again")
    public static let WALLET_PIN_CONFIRM_AGAIN_SUBTITLE = LocalizedString("wallet_pin_confirm_again_subtitle", comment: "It's rare to see a third confirmation somewhere else, so please remember the PIN is unrecoverable if lost.")
    public static let WALLET_PIN_NEW_TITLE = LocalizedString("wallet_pin_new_title", comment: "Set a new PIN")
    public static let WALLET_PIN_VERIFY_TITLE = LocalizedString("wallet_pin_verify_title", comment: "Enter the 6 digit PIN to verify")
    public static let WALLET_PIN_INCONSISTENCY = LocalizedString("wallet_pin_inconsistency", comment: "The PIN is not the same twice, please reset it")
    public static let WALLET_PIN_TOO_SIMPLE = LocalizedString("wallet_pin_too_simple", comment: "The PIN is too simple and insecure.")
    public static let WALLET_PIN_REMEMBER_DESCRIPTION = LocalizedString("wallet_pin_remember_description", comment: "You'll be asked for it periodically to help you remember it.")
    public static let WALLET_ALL_TRANSACTIONS_TITLE = LocalizedString("wallet_all_transactions_title", comment: "All Transactions")
    public static let WALLET_PIN_TOUCH_ID_PROMPT = LocalizedString("wallet_pin_touch_id_prompt", comment: "Confirm PIN to enable Touch Pay")
    public static let WALLET_PIN_FACE_ID_PROMPT = LocalizedString("wallet_pin_face_id_prompt", comment: "Confirm PIN to enable Face Pay")
    public static func WALLET_ENABLE_BIOMETRIC_PAY_TITLE(biometricType: String) -> String {
        return String(format: LocalizedString("wallet_enable_biometric_pay_title", comment: "Pay with %@"), biometricType)
    }
    public static func WALLET_ENABLE_BIOMETRIC_PAY_PROMPT(biometricType: String) -> String {
        return String(format: LocalizedString("wallet_enable_biometric_pay_prompt", comment: "Once enabled, %@ can be used to make quick transfers"), biometricType)
    }
    public static func WALLET_BIOMETRIC_PAY_PROMPT(biometricType: String) -> String {
        return String(format: LocalizedString("wallet_biometric_pay_prompt", comment: "Authorize payment via %@"), biometricType)
    }
    public static func WALLET_DISABLE_BIOMETRIC_PAY(biometricType: String) -> String {
        return String(format: LocalizedString("wallet_disable_biometric_pay", comment: "Disable %@ Pay"), biometricType)
    }
    public static let WALLET_PIN_PAY_INTERVAL = LocalizedString("wallet_pin_pay_interval", comment: "Pay with PIN interval")
    public static func WALLET_PIN_PAY_INTERVAL_MINUTES(_ seconds: Double) -> String {
        return String(format: LocalizedString("wallet_pin_pay_interval_minutes", comment: "%@ Minutes"), "\(Int(seconds / 60))")
    }
    public static let WALLET_PIN_PAY_INTERVAL_HOUR = LocalizedString("wallet_pin_pay_interval_hour", comment: "1 Hour")
    public static func WALLET_PIN_PAY_INTERVAL_HOURS(_ seconds: Double) -> String {
        return String(format: LocalizedString("wallet_pin_pay_interval_hours", comment: "%@ Hours"), "\(Int(seconds / 3600))")
    }
    public static func WALLET_PIN_PAY_INTERVAL(_ seconds: Double) -> String {
        if seconds < 60 * 60 {
            return WALLET_PIN_PAY_INTERVAL_MINUTES(seconds)
        } else if seconds == 60 * 60 {
            return WALLET_PIN_PAY_INTERVAL_HOUR
        } else {
            return WALLET_PIN_PAY_INTERVAL_HOURS(seconds)
        }
    }
    public static let WALLET_PIN_PAY_INTERVAL_CONFIRM = LocalizedString("wallet_pin_pay_interval_confirm", comment: "Confirm PIN to protect your settings security.")
    public static let WALLET_PIN_PAY_INTERVAL_TIPS = LocalizedString("wallet_pin_pay_interval_tips", comment: "For the security of your assets, you will still need to pay the PIN when you transfer again when you have entered the payment PIN for more than the specified time")
    public static let TRANSACTIONS_FILTER_SORT_BY = LocalizedString("transactions_filter_sort_by", comment: "Sort by")
    public static let TRANSACTIONS_FILTER_SORT_BY_TIME = LocalizedString("transactions_filter_sort_by_time", comment: "Time")
    public static let TRANSACTIONS_FILTER_SORT_BY_AMOUNT = LocalizedString("transactions_filter_sort_by_amount", comment: "Amount")
    public static let TRANSACTIONS_FILTER_FILTER_BY = LocalizedString("transactions_filter_filter_by", comment: "Filter by")
    public static let TRANSACTIONS_FILTER_FILTER_BY_ALL = LocalizedString("transactions_filter_filter_by_all", comment: "All")
    public static func PENDING_DEPOSIT_CONFIRMATION(numerator: Int, denominator: Int?) -> String {
        var progress = String(numerator)
        if let denominator = denominator {
            progress += "/\(denominator)"
        }
        return String(format: LocalizedString("pending_deposit_confirmation", comment: "%@ confirmations"), progress)
    }

    // Transaction
    public static let TRANSACTION_TITLE = LocalizedString("transaction_title", comment: "Transaction")
    public static let TRANSACTION_ID = LocalizedString("transaction_id", comment: "Transaction Id")
    public static let TRANSACTION_TYPE = LocalizedString("transaction_type", comment: "Transaction Type")
    public static let TRANSACTION_ASSET = LocalizedString("transaction_asset", comment: "Asset Type")
    public static let TRANSACTION_MEMO = LocalizedString("transaction_memo", comment: "Memo")
    public static let TRANSACTION_DATE = LocalizedString("transaction_date", comment: "Date")
    public static let TRANSACTION_SENDER = LocalizedString("transaction_sender", comment: "Sender")
    public static let TRANSACTION_RECEIVER = LocalizedString("transaction_receiver", comment: "Receiver")
    public static let TRANSACTION_TYPE_DEPOSIT = LocalizedString("transaction_type_deposit", comment: "Deposit")
    public static let TRANSACTION_TYPE_TRANSFER = LocalizedString("transaction_type_transfer", comment: "Tansfer")
    public static let TRANSACTION_TYPE_WITHDRAWAL = LocalizedString("transaction_type_withdrawal", comment: "Withdrawal")
    public static let TRANSACTION_TYPE_FEE = LocalizedString("transaction_type_fee", comment: "Fee")
    public static let TRANSACTION_TYPE_REBATE = LocalizedString("transaction_type_rebate", comment: "Rebate")
    
    // Address Book
    public static func ADDRESS_BOOK_TITLE(symbol: String) -> String {
        return String(format: LocalizedString("address_book_title", comment: "%@ Address Book"), symbol)
    }
    public static let ADDRESS_LIST_TITLE = LocalizedString("address_list_title", comment: "Address")
    public static func ADDRESS_NEW_TITLE(symbol: String) -> String {
        return String(format: LocalizedString("address_new_title", comment: "New %@ Address"), symbol)
    }
    public static func ADDRESS_EDIT_TITLE(symbol: String) -> String {
        return String(format: LocalizedString("address_edit_title", comment: "Edit %@ Address"), symbol)
    }
    public static func ADDRESS_DELETE_TITLE(symbol: String) -> String {
        return String(format: LocalizedString("address_delete_title", comment: "Delete %@ Address"), symbol)
    }
    
    // Transfer
    public static let TRANSFER_TOUCH_ID_REASON = LocalizedString("transfer_touch_id_reason", comment: "Use an existing fingerprint to make the payment")
    public static func PAY_TRANSFER_TITLE(fullname: String) -> String {
        return String(format: LocalizedString("pay_transfer_title", comment: "Transfer to %@"), fullname)
    }

    // Setting
    public static let SETTING_BLOCKED = LocalizedString("setting_blocked", comment: "Blocked Users")
    public static let SETTING_BLOCKED_EMPTY = LocalizedString("setting_blocked_empty", comment: "No blocked users")
    public static let SETTING_NO_AUTHORIZATIONS = LocalizedString("setting_no_authorizations", comment: "NO AUTHORIZATIONS")

    public static let SETTING_NOTIFICATION_MESSAGE = LocalizedString("setting_notification_message", comment: "MESSAGE NOTIFICATIONS")
    public static let SETTING_NOTIFICATION_MESSAGE_SUMMARY = LocalizedString("setting_notification_message_summary", comment: "You can set custom notifications for specific users on their Contact page.")
    public static let SETTING_NOTIFICATION_GROUP = LocalizedString("setting_notification_group", comment: "GROUP NOTIFICATIONS")
    public static let SETTING_NOTIFICATION_GROUP_SUMMARY = LocalizedString("setting_notification_group_summary", comment: "You can set custom notifications for specific groups on their Group Info page.")
    public static let SETTING_PRIVACY_AND_SECURITY_TITLE = LocalizedString("setting_privacy_and_security_title", comment: "PRIVACY")
    public static func SETTING_DESKTOP_LAST_ACTIVE(time: String) -> String {
        return String(format: LocalizedString("setting_desktop_last_active", comment: "Last active %@"), time)
    }
    public static let SETTING_DESKTOP_DESKTOP_ON = LocalizedString("setting_desktop_desktop_on", comment: "You have your desktop logged in")
    public static let SETTING_DESKTOP_LOG_OUT = LocalizedString("setting_desktop_log_out", comment: "Log out from desktop")
    public static let SETTING_AUTHORIZATIONS = LocalizedString("setting_authorizations", comment: "Authorizations")
    public static let SETTING_STORAGE_USAGE = LocalizedString("setting_storage_usage", comment: "Storage Usage")
    public static func SETTING_STORAGE_USAGE_CLEAR(messageCount: Int, size: String) -> String {
        return String(format: LocalizedString("setting_storage_usage_clear", comment: "Clear %@ messages (%@)?"), "\(messageCount)", size)
    }
    public static let SETTING_LOGOUT = LocalizedString("setting_logout", comment: "Log Out")
    public static let SETTING_BACKUP_AUTO = LocalizedString("setting_backup_auto", comment: "Auto Backup")
    public static let SETTING_BACKUP_NOW = LocalizedString("setting_backup_now", comment: "Back Up Now")
    public static let SETTING_BACKUP_DAILY = LocalizedString("setting_backup_daily", comment: "Daily")
    public static let SETTING_BACKUP_WEEKLY = LocalizedString("setting_backup_weekly", comment: "Weekly")
    public static let SETTING_BACKUP_MONTHLY = LocalizedString("setting_backup_monthly", comment: "Monthly")
    public static let SETTING_BACKUP_OFF = LocalizedString("setting_backup_off", comment: "Off")
    public static let SETTING_BACKUP_AUTO_TIPS = LocalizedString("setting_backup_auto_tips", comment: "Automatically back up to iCloud only over Wi-Fi.")
    public static let SETTING_BACKUP_DISABLE_TIPS = LocalizedString("setting_backup_disable_tips", comment: "Sign in to iCloud to back up your history. Settings > iCloud > Turn on iCloud Drive.")
    public static func SETTING_BACKUP_LAST(time: String, size: String) -> String {
        return String(format: LocalizedString("setting_backup_last", comment: "Last backup at %@, total size %@"), time, size)
    }
    public static func SETTING_RESTORE_PROGRESS(progress: String) -> String {
        return String(format: LocalizedString("setting_restore_progress", comment: "Restoring %@"), progress)
    }
    
    public static let REPORT_TITLE = LocalizedString("report_title", comment: "Send the conversation log to developers?")
    public static let REPORT_BUTTON = LocalizedString("report_button", comment: "Send")
    
    // Screen lock
    public static func SCREEN_LOCK_TIMEOUT_INTERVAL(_ seconds: Double) -> String {
        if seconds == 0 {
            return R.string.localizable.setting_screen_lock_timeout_immediately()
        } else if seconds == 60 * 60 {
            return R.string.localizable.setting_screen_lock_timeout_hour()
        } else if seconds == 60 {
            return R.string.localizable.setting_screen_lock_timeout_one_minute()
        } else {
            return R.string.localizable.setting_screen_lock_timeout_minutes("\(Int(seconds / 60))")
        }
    }
}
