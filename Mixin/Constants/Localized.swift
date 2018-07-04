import Foundation

public class Localized {

    // Common
    public static let DIALOG_BUTTON_OK = LocalizedString("dialog_button_ok", comment: "OK")
    public static let DIALOG_BUTTON_CANCEL = LocalizedString("dialog_button_cancel", comment: "Cancel")
    public static let DIALOG_BUTTON_CHANGE = LocalizedString("dialog_button_change", comment: "Change")
    public static let DIALOG_BUTTON_CONFIRM = LocalizedString("dialog_button_confirm", comment: "Confirm")
    public static let CONNECTION_HINT_CONNECTING = LocalizedString("connection_hint_connecting", comment: "Connecting")
    public static let CONNECTION_HINT_WAITING = LocalizedString("connection_hint_waiting", comment: "Waiting to reconnect")
    public static let ACTION_NEXT = LocalizedString("action_next", comment: "Next")
    public static let ACTION_REMOVE = LocalizedString("action_remove", comment: "Remove")
    public static let ACTION_CAMERA = LocalizedString("action_camera", comment: "Camera")
    public static let ACTION_DONE = LocalizedString("action_done", comment: "Done")
    public static let ACTION_CHOOSE_PHOTO = LocalizedString("action_choose_photo", comment: "Choose Photo")
    public static let ACTION_SAVE = LocalizedString("action_save", comment: "Save")
    public static let ACTION_SEE_MORE = LocalizedString("action_see_more", comment: "See more")
    public static let ACTION_OPEN_SAFARI = LocalizedString("action_open_safari", comment: "Open in Safari")
    public static let ACTION_REFRESH = LocalizedString("action_refresh", comment: "Refresh")
    public static let ACTION_SELECT = LocalizedString("action_select", comment: "Select")
    public static let ACTION_CLEAR = LocalizedString("action_clear", comment: "Clear")
    public static let MENU_DELETE = LocalizedString("menu_delete", comment: "Delete")

    public static let DATE_FORMAT_DAY = LocalizedString("date_format_day", comment: "hh:mm a")
    public static let DATE_FORMAT_DATE = LocalizedString("date_format_date", comment: "dd/MM/yyyy")
    public static let DATE_FORMAT_MONTH = LocalizedString("date_format_month", comment: "E, d MMM")
    public static let DATE_FORMAT_TRANSATION = LocalizedString("date_format_transation", comment: "MMM dd, HH:mm")

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
    public static let TOAST_SERVER_ERROR = LocalizedString("toast_server_error", comment: "Server is under maintenance")
    public static let TOAST_API_ERROR_FORBIDDEN = LocalizedString("toast_api_error_forbidden", comment: "Access denied")
    public static let TOAST_API_ERROR_NO_CONNECTION = LocalizedString("toast_api_error_no_connection", comment: "No network connection")
    public static let TOAST_API_ERROR_CONNECTION_TIMEOUT = LocalizedString("toast_api_error_connection_timeout", comment: "Network connection timeout")
    public static let TOAST_API_ERROR_NETWORK_CONNECTION_LOST = LocalizedString("toast_api_error_network_connection_lost", comment: "The network connection was lost, please check your network and try again later")
    public static let TOAST_API_ERROR_SERVER_5XX = LocalizedString("toast_api_error_server_5xx", comment: "Minewave server encounters errors")
    public static let TOAST_API_ERROR_NOT_FOUND = LocalizedString("toast_api_error_not_found", comment: "Not found")
    public static let TOAST_API_ERROR_SERVER_DATA_ERROR = LocalizedString("toast_api_error_server_data_error", comment: "Data parsing error")
    public static let TOAST_API_ERROR_TOO_MANY_REQUESTS = LocalizedString("toast_api_error_too_many_requests", comment: "Rate limit exceeded")
    public static func TOAST_API_ERROR_PHONE_SMS_DELIVERY(phoneNumber: String) -> String {
        return String(format: LocalizedString("toast_api_error_phone_sms_delivery", comment: "Failed to deliver SMS to %@"), phoneNumber)
    }
    public static let TOAST_API_ERROR_PHONE_VERIFICATION_INVALID = LocalizedString("toast_api_error_phone_verification_invalid", comment: "Invalid verification code")
    public static let TOAST_API_ERROR_UNAVAILABLE_PHONE_NUMBER = LocalizedString("toast_api_error_unavailable_phone_number", comment: "This phone number is already associated with another account")
    public static let PERMISSION_DENIED_CAMERA = LocalizedString("permission_denied_camera", comment: "Mixin doesn't have permission to use your camera. Please tap Setting to open system settings.")
    public static let PERMISSION_DENIED_PHOTO_LIBRARY = LocalizedString("permission_denied_photo_library", comment: "Mixin doesn't have permission to use your photo library. Please tap Setting to open system settings.")
    public static let PERMISSION_DENIED_MICROPHONE = LocalizedString("permission_denied_microphone", comment: "Mixin doesn't have permission to use your microphone. Please tap Setting to open system settings.")
    public static let TOAST_OPERATION_FAILED = LocalizedString("toast_operation_failed", comment: "The operation failed, please try again later")
    public static let TOAST_ADDED = LocalizedString("toast_added", comment: "Added")

    // Login
    public static func NAVIGATION_TITLE_ENTER_VERIFICATION_CODE(mobileNumber: String) -> String {
        return String(format: LocalizedString("navigation_title_enter_verification_code", comment: "Enter the 4-digit code sent to you at %@"), mobileNumber)
    }
    public static let TEXT_INTRO = LocalizedString("text_intro", comment: "A messenger that transfers all crypto currencies with end to end encryption. Tap \"%@\" to accept %@ and %@")
    public static let TEXT_CONFIRM_SEND_CODE = LocalizedString("text_confirm_send_code", comment: "Please confirm the phone number %@")
    public static let BUTTON_TITLE_AGREE_AND_CONTINUE = LocalizedString("button_title_agree_and_continue", comment: "Agree & Continue")
    public static let BUTTON_TITLE_TERMS_OF_SERVICE = LocalizedString("button_title_terms_of_service", comment: "Terms of Service")
    public static let BUTTON_TITLE_PRIVACY_POLICY = LocalizedString("button_title_privacy_policy", comment: "Privacy Policy")
    public static let BUTTON_TITLE_RESEND_CODE = LocalizedString("button_title_resend_code", comment: "Resend code")
    public static let BUTTON_TITLE_RESEND_CODE_PENDING = LocalizedString("button_title_resend_code_pending", comment: "Resend code in %@")
    public static let HEADER_TITLE_CURRENT_SELECTED = LocalizedString("header_title_current_selected", comment: "Current Selected")
    public static let HEADER_TITLE_CURRENT_LOCATION = LocalizedString("header_title_current_location", comment: "Current Location")
    public static let TOAST_RECAPTCHA_TIMED_OUT = LocalizedString("toast_recaptcha_timed_out", comment: "Validation timed out")
    public static let TOAST_RECAPTCHA_INVALID = LocalizedString("toast_recaptcha_invalid", comment: "Recaptcha is invalid.")
    public static let TOAST_UPDATE_TIPS = LocalizedString("toast_update_tips", comment: "Please update Mixin from App Store to continue use the service.")

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
    public static let CONTACT_INVITE = LocalizedString("contact_invite", comment: "Hey, I'm using Mixin Messenger to chat. Download it here: https://mixin.one .")
    public static let CONTACT_PROFILE_TITLE = LocalizedString("contact_profile_title", comment: "My Profile")
    public static let CONTACT_TITLE = LocalizedString("contact_title", comment: "Contacts")
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
    public static let CONTACT_SEARCH_NOT_FOUND = LocalizedString("contact_search_not_found", comment: "user not found")
    public static let CONTACT_AVATAR_PICKING_FAIL = LocalizedString("contact_avatar_picking_fail", comment: "Failed to change your profile photo")
    public static let CONTACT_CHANGE_NAME_FAIL = LocalizedString("contact_change_name_fail", comment: "Failed to change your name")

    // Chat
    public static let CHAT_MESSAGE_MENU_REPLY = LocalizedString("chat_message_menu_reply", comment: "Reply")
    public static let CHAT_MESSAGE_MENU_FORWARD = LocalizedString("chat_message_menu_forward", comment: "Forward")
    public static let CHAT_MESSAGE_MENU_COPY = LocalizedString("chat_message_menu_copy", comment: "Copy")
    public static let CHAT_MESSAGE_OPEN_URL = LocalizedString("chat_message_open_url", comment: "Open URL")
    public static let CHAT_MESSAGE_ADD = LocalizedString("chat_message_sticker", comment: "Add to Stickers")
    public static let CHAT_TIME_TODAY = LocalizedString("chat_time_today", comment: "Today")
    public static let CHAT_MESSAGE_YOU = LocalizedString("chat_message_you", comment: "You")
    public static func CHAT_MESSAGE_CREATED(fullName: String) -> String {
        return String(format: LocalizedString("chat_message_created", comment: "%@ created this group"), fullName)
    }
    public static func CHAT_MESSAGE_REMOVED(adminFullName: String, participantFullName: String) -> String {
        return String(format: LocalizedString("chat_message_removed", comment: "%@ removed %@"), adminFullName, participantFullName)
    }
    public static func CHAT_MESSAGE_ADDED(inviterFullName: String, inviteeFullName: String) -> String {
        return String(format: LocalizedString("chat_message_added", comment: "%@ added %@"), inviterFullName, inviteeFullName)
    }
    public static func CHAT_MESSAGE_LEFT(fullName: String) -> String {
        return String(format: LocalizedString("chat_message_left", comment: "%@ left"), fullName)
    }
    public static func CHAT_MESSAGE_JOINED(fullName: String) -> String {
        return String(format: LocalizedString("chat_message_joined", comment: "%@ joined"), fullName)
    }
    public static func CHAT_MESSAGE_CHANGED_TITLE(fullName: String, title: String) -> String {
        return String(format: LocalizedString("chat_message_changed_title", comment: "%@ changed the subject to %@"), fullName, title)
    }
    public static func CHAT_MESSAGE_ADMIN(fullName: String) -> String {
        return String(format: LocalizedString("chat_message_admin", comment: "%@ now an admin"), fullName)
    }
    public static let CHAT_CELL_TITLE_ENCRYPTION = LocalizedString("chat_cell_title_encryption", comment: "Messages to this conversation are encrypted end-to-end, click for more information")
    public static let CHAT_CELL_TITLE_UNKNOWN_CATEGORY = LocalizedString("chat_cell_title_unknown_category", comment: "This type of message is not supported, please upgrade Mixin to the latest version.")
    public static let CHAT_FORWARD_TITLE = LocalizedString("chat_forward_title", comment: "Forward")
    public static let CHAT_FORWARD_CHATS = LocalizedString("chat_forward_chats", comment: "CHATS")
    public static let CHAT_FORWARD_CONTACTS = LocalizedString("chat_forward_contacts", comment: "CONTACTS")
    public static func CHAT_DECRYPTION_FAILED_HINT(username: String) -> String {
        return String(format: LocalizedString("chat_decryption_failed_hint", comment: "Waiting for %@ to get online and establish an encrypted session. "), username)
    }
    public static let CHAT_DECRYPTION_FAILED_LINK = LocalizedString("chat_decryption_failed_link", comment: "learn more.")
    public static let CHAT_SEND_PHOTO_FAILED = LocalizedString("chat_send_photo_failed", comment: "Failed to send photo")
    public static let CHAT_SEND_FILE_FAILED = LocalizedString("chat_send_file_failed", comment: "Failed to send file")
    public static let CHAT_SEND_VIDEO_FAILED = LocalizedString("chat_send_video_failed", comment: "Failed to send video")
    public static let CHAT_SEND_AUDIO_FAILED = LocalizedString("chat_send_audio_failed", comment: "Failed to send audio")
    public static let CHAT_MENU_CAMERA = LocalizedString("chat_menu_camera", comment: "Camera")
    public static let CHAT_MENU_PHOTO = LocalizedString("chat_menu_photo", comment: "Photo & Video")
    public static let CHAT_MENU_FILE = LocalizedString("chat_menu_file", comment: "File")
    public static let CHAT_MENU_TRANSFER = LocalizedString("chat_menu_transfer", comment: "Transfer")
    public static let CHAT_MENU_CONTACT = LocalizedString("chat_menu_contact", comment: "Contact")
    public static let CHAT_PHOTO_SAVE = LocalizedString("chat_photo_save", comment: "Save to Camera Roll")
    public static let CHAT_FILE_EXPIRED = LocalizedString("chat_file_expired", comment: "Expired")
    public static let CHAT_VOICE_RECORD_LONGPRESS_HINT = LocalizedString("chat_voice_record_longpress_hint", comment: "Hold to record, release to send.")

    // Sticker
    public static let STICKER_MANAGER_TITLE = LocalizedString("sticker_manager_title", comment: "My Stickers")
    public static let STICKER_ADD_TITLE = LocalizedString("sticker_add_title", comment: "Add Sticker")
    public static let STICKER_REMOVE_TITLE = LocalizedString("sticker_remove_title", comment: "Delete Stickers")
    public static let STICKER_ADD_FAILED = LocalizedString("sticker_add_failed", comment: "Failed to add sticker")
    public static let STICKER_REMOVE_FAILED = LocalizedString("sticker_remove_failed", comment: "Failed to delete stickers")
    public static let STICKER_ADD_REQUIRED = LocalizedString("sticker_add_required", comment: "Requires stickers file size larger than 1KB and less than 1MB, aspect ratio between 16:9 and 9:16.")
    public static let STICKER_ADD_LIMIT = LocalizedString("sticker_add_limit", comment: "Too many stickers.")

    // Camera
    public static let CAMERA_SAVE_PHOTO_SUCCESS = LocalizedString("camera_save_photo_success", comment: "Photo saved.")
    public static let CAMERA_SAVE_PHOTO_FAILED = LocalizedString("camera_save_photo_failed", comment: "Unable to save photo.")
    public static let CAMERA_SEND_TO_TITLE = LocalizedString("camera_send_to_title", comment: "Send To")
    public static let CAMERA_SAVE_VIDEO_SUCCESS = LocalizedString("camera_save_video_success", comment: "Video saved.")
    public static let CAMERA_SAVE_VIDEO_FAILED = LocalizedString("camera_save_video_failed", comment: "Unable to save video.")
    public static let IMAGE_PICKER_TITLE_ALBUMS = LocalizedString("image_picker_title_albums", comment: "Albums")
    public static let CAMERA_QRCODE_CODES = LocalizedString("camera_qrcode_codes", comment: "Detected a Mixin QR code, tap to recognize")

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
    public static let GROUP_PARTICIPANT_MENU_ADMIN = LocalizedString("group_participant_menu_admin", comment: "Make Group Admin")
    public static let GROUP_PARTICIPANT_MENU_REMOVE = LocalizedString("group_participant_menu_remove", comment: "Remove from Group")
    public static let GROUP_JOIN_FAIL_TITLE = LocalizedString("group_join_fail_title", comment: "Couldn't Join Group")
    public static let GROUP_JOIN_FAIL_SUMMARY = LocalizedString("group_join_fail_summary", comment: "This invite link doesn't match any Mixin groups.")
    public static let CODE_RECOGNITION_FAIL_TITLE = LocalizedString("code_recognition_fail_title", comment: "Unrecognized codes")
    public static let CODE_RECOGNITION_FAIL_SUMMARY = LocalizedString("code_recognition_fail_summary", comment: "This codes doesn't match any Mixin groups or users.")
    public static let GROUP_JOIN_FAIL_FULL = LocalizedString("group_join_fail_full", comment: "The group chat is full.")
    public static let GROUP_LINK_CHECKING = LocalizedString("group_link_checking", comment: "Checking invite link")
    public static let GROUP_REMOVE_TITLE = LocalizedString("group_remove_title", comment: "you were removed from the group")
    public static let GROUP_MENU_CLEAR = LocalizedString("group_menu_clear", comment: "Clear Chat")
    public static let GROUP_MENU_DELETE = LocalizedString("group_menu_delete", comment: "Delete Chat")
    public static let GROUP_MENU_EXIT = LocalizedString("group_menu_exit", comment: "Delete and Exit")
    public static let GROUP_MENU_ANNOUNCEMENT = LocalizedString("group_menu_announcement", comment: "Edit Group Description")
    public static let GROUP_MENU_PARTICIPANTS = LocalizedString("group_menu_participants", comment: "Participants")

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

    // Profile
    public static let PROFILE_TITLE = LocalizedString("profile_title", comment: "Info")
    public static func PROFILE_MIXIN_ID(id: String) -> String {
        return String(format: LocalizedString("profile_mixin_id", comment: "Mixin ID: %@"), id)
    }
    public static func PROFILE_REPUTATION_SCORE(reputation: Int) -> String {
        return String(format: LocalizedString("profile_reputation_score", comment: "Reputation Score: %@"), String(reputation))
    }
    public static let PROFILE_SHARE_CARD = LocalizedString("profile_share_card", comment: "Share Contact")
    public static let PROFILE_ADD = LocalizedString("profile_add", comment: "Add Contact")
    public static let PROFILE_REMOVE = LocalizedString("profile_remove", comment: "Remove Contact")
    public static let PROFILE_BLOCK = LocalizedString("profile_block", comment: "Block")
    public static let PROFILE_UNBLOCK = LocalizedString("profile_unblock", comment: "Unblock")
    public static func PROFILE_INVITATION_CODE_CONSUMED_COUNT(consumed_count: Int) -> String {
        return String(format: LocalizedString("profile_invitation_code_consumed_count", comment: "You have invited a total of %@ people."), String(consumed_count))
    }
    public static let PROFILE_FULL_NAME = LocalizedString("profile_full_name", comment: "Name")
    public static let PROFILE_EDIT_NAME = LocalizedString("profile_edit_name", comment: "Edit Name")
    public static let PROFILE_ADD_CONTACT_FAIL = LocalizedString("profile_add_contact_fail", comment: "Failed to add contact")
    public static let PROFILE_REMOVE_CONTACT_FAIL = LocalizedString("profile_remove_contact_fail", comment: "Failed to remove contact")
    public static let PROFILE_MUTE_DURATION_8H = LocalizedString("profile_mute_duration_8h", comment: "8 hours")
    public static let PROFILE_MUTE_DURATION_1WEEK = LocalizedString("profile_mute_duration_1week", comment: "1 week")
    public static let PROFILE_MUTE_DURATION_1YEAR = LocalizedString("profile_mute_duration_1year", comment: "1 year")
    public static let PROFILE_UNMUTE = LocalizedString("profile_unmute", comment: "Unmute")
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
    public static let WALLET_TRANSFER_OUT = LocalizedString("wallet_transfer_out", comment: "Transfer Out")
    public static let TRANSFER_ERROR_BALANCE_INSUFFICIENT = LocalizedString("transfer_error_balance_insufficient", comment: "Insufficient balance")
    public static let TRANSFER_ERROR_FEE_INSUFFICIENT = LocalizedString("transfer_error_fee_insufficient", comment: "Insufficient transaction fee")
    public static let TRANSFER_ERROR_AMOUNT_TOO_SMALL = LocalizedString("transfer_error_amount_too_small", comment: "Transfer amount too small")
    public static let TRANSFER_ERROR_PIN_INCORRECT = LocalizedString("transfer_error_pin_incorrect", comment: "PIN incorrect")
    public static let WALLET_SYMBOL_OTHER = LocalizedString("wallet_symbol_other", comment: "Other")
    public static let WALLET_TRANSFER_BALANCE_INSUFFICIENT = LocalizedString("wallet_transfer_balance_insufficient", comment: "Insufficient balance")
    public static let WALLET_PIN_INCONSISTENCY = LocalizedString("wallet_pin_inconsistency", comment: "Passwords do not match")
    public static let WALLET_PIN_VERIFY_TIPS = LocalizedString("wallet_pin_verify_tips", comment: "Please enter the 6 digit PIN to verify.")
    public static let WALLET_CHANGE_PASSWORD = LocalizedString("wallet_change_password", comment: "Change PIN")
    public static let WALLET_PASSWORD_VERIFY_TITLE = LocalizedString("wallet_password_verify_title", comment: "Old PIN")
    public static let WALLET_CHANGE_PASSWORD_SUCCESS = LocalizedString("wallet_change_password_success", comment: "Change wallet PIN successfully")
    public static let WALLET_SET_PASSWORD_SUCCESS = LocalizedString("wallet_set_password_success", comment: "Set wallet PIN successfully")
    public static let WALLET_SNAPSHOT_FROM = LocalizedString("wallet_snapshot_from", comment: "Set wallet PIN successfully")
    public static func WALLET_SNAPSHOT_FROM(fullName: String) -> String {
        return String(format: LocalizedString("wallet_snapshot_from", comment: "From %@"), fullName)
    }
    public static func WALLET_SNAPSHOT_TO(fullName: String) -> String {
        return String(format: LocalizedString("wallet_snapshot_to", comment: "To %@"), fullName)
    }
    public static let WALLET_DEPOSIT = LocalizedString("wallet_deposit", comment: "Deposit")
    public static func WALLET_DEPOSIT_CONFIRMATIONS(confirmations: Int) -> String {
        return String(format: LocalizedString("wallet_deposit_confirmations", comment: "Deposit will arrive after at least %@ block confirmations."), "\(confirmations)")
    }
    public static let WALLET_MENU_SHOW_HIDDEN_ASSETS = LocalizedString("wallet_menu_show_hidden_assets", comment: "Hidden assets")
    public static let WALLET_MENU_SHOW_ASSET = LocalizedString("wallet_menu_show_asset", comment: "Show asset")
    public static let WALLET_MENU_HIDE_ASSET = LocalizedString("wallet_menu_hide_asset", comment: "Hide asset")
    public static let WALLET_HIDE_ASSET_EMPTY = LocalizedString("wallet_hide_asset_empty", comment: "No hidden assets")
    public static let WALLET_MENU_WITHDRAW = LocalizedString("wallet_menu_withdraw", comment: "Withdraw")
    public static func WALLET_HINT_TRANSACTION_FEE(feeRepresentation: String, name: String) -> String {
        return String(format: LocalizedString("wallet_hint_transaction_fee", comment: "A transaction fee of %@ is required for withdrawing %@."), feeRepresentation, name)
    }
    public static let WALLET_PIN_TIPS_DESCRIPTION = LocalizedString("wallet_pin_tips_description", comment: "You'll be asked for it periodically to help you remember it.")
    public static let WALLET_PASSWORD_ADDRESS_TIPS = LocalizedString("wallet_password_address_tips", comment: "Confirm PIN to protect your address security.")
    public static func WALLET_WITHDRAWAL_ASSET(assetName: String) -> String {
        return String(format: LocalizedString("wallet_withdrawal_asset", comment: "%@ Withdrawal"), assetName)
    }
    public static let WALLET_WITHDRAWAL_PAY_PASSWORD = LocalizedString("wallet_withdrawal_pay_password", comment: "Withdrawal with PIN")
    public static func WALLET_WITHDRAWAL_RESERVE(reserveRepresentation: String, name: String) -> String {
        return String(format: LocalizedString("wallet_withdrawal_reserve", comment: " %@ has a minimum %@ reserve requirement."), name, reserveRepresentation)
    }
    public static let WALLET_BLOCKCHIAN_NOT_IN_SYNC = LocalizedString("wallet_blockchian_not_in_sync", comment: "Blockchain not in sync.")
    public static let WALLET_NO_PRICE = LocalizedString("wallet_no_price", comment: "N/A")
    public static let WALLET_PIN_INIT_TIPS1 = LocalizedString("wallet_pin_init_tips1", comment: "Please set a 6 digit PIN.")
    public static let WALLET_PIN_INIT_TIPS2 = LocalizedString("wallet_pin_init_tips2", comment: "Please confirm the 6 digit PIN and remember it. If lost, there is no way to recover your wallet.")
    public static let WALLET_PIN_INIT_TIPS3 = LocalizedString("wallet_pin_init_tips3", comment: "Please confirm your 6 digit PIN again. It's rare to see a third confirmation somewhere else, so please remember the PIN is unrecoverable if lost.")
    public static let WALLET_PIN_INIT_TIPS4 = LocalizedString("wallet_pin_init_tips4", comment: "Yes, there is a forth PIN confirmation, and I promise it's the last one to ensure you have remembered your PIN. The PIN is unrecoverable if lost.")
    public static let WALLET_PIN_CHANGE_TIPS = LocalizedString("wallet_pin_change_tips", comment: "Please set a new 6 digit PIN.")
    public static let WALLET_PIN_INIT_TITLE = LocalizedString("wallet_pin_init_title", comment: "Set PIN")
    public static let WALLET_PIN_CONFIRM_TITLE = LocalizedString("wallet_pin_confirm_title", comment: "Confirm PIN")
    public static let WALLET_PIN_NEW_TITLE = LocalizedString("wallet_pin_new_title", comment: "Set a new PIN")
    public static let WALLET_ALL_TRANSACTIONS_TITLE = LocalizedString("wallet_all_transactions_title", comment: "All Transactions")

    // Transaction
    public static let TRANSACTION_TITLE = LocalizedString("transaction_title", comment: "Transaction")
    public static let TRANSACTION_ID = LocalizedString("transaction_id", comment: "Transaction Id")
    public static let TRANSACTION_TYPE = LocalizedString("transaction_type", comment: "Transaction Type")
    public static let TRANSACTION_ASSET = LocalizedString("transaction_asset", comment: "Asset Type")
    public static let TRANSACTION_MEMO = LocalizedString("transaction_memo", comment: "Memo")
    public static let TRANSACTION_DATE = LocalizedString("transaction_date", comment: "Date")
    public static let TRANSACTION_SENDER = LocalizedString("transaction_sender", comment: "Sender")
    public static let TRANSACTION_RECEIVER = LocalizedString("transaction_receiver", comment: "Receiver")
    public static let TRANSACTION_TRANSACTION_HASH = LocalizedString("transaction_transaction_hash", comment: "Transaction Hash")
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
    public static let ADDRESS_FORMAT_ERROR = LocalizedString("address_format_error", comment: "Invalid address format.")
    
    public static let TOAST_COPIED = LocalizedString("toast_copied", comment: "Successfully copied to clipboard")

    // Transfer
    public static func TRANSFER_TITLE_TO(fullName: String) -> String {
        return String(format: LocalizedString("transfer_title_to", comment: "to %@"), fullName)
    }
    public static let TRANSFER_TRANSACTIONS = LocalizedString("transfer_transactions", comment: "TRANSACTIONS")
    public static let TRANSFER_TOUCH_ID_REASON = LocalizedString("transfer_touch_id_reason", comment: "Use an existing fingerprint to make the payment")
    public static let TRANSFER_PAID = LocalizedString("transfer_paid", comment: "Paid")
    public static let TRANSFER_PAY_PASSWORD = LocalizedString("transfer_pay_password", comment: "Pay with PIN")
    public static func PAY_TRANSFER_TITLE(fullname: String) -> String {
        return String(format: LocalizedString("pay_transfer_title", comment: "Transfer to %@"), fullname)
    }
    public static func PAY_WITHDRAWAL_TITLE(label: String) -> String {
        return String(format: LocalizedString("pay_withdrawal_title", comment: "Withdrawal to %@"), label)
    }

    // Setting
    public static let SETTING_TITLE = LocalizedString("setting_title", comment: "Setting")
    public static let SETTING_NOTIFICATION = LocalizedString("setting_notification", comment: "Notifications")
    public static let SETTING_CONVERSATION = LocalizedString("setting_conversation", comment: "Conversation")
    public static let SETTING_BLOCKED = LocalizedString("setting_blocked", comment: "Blocked Users")
    public static let SETTING_BLOCKED_EMPTY = LocalizedString("setting_blocked_empty", comment: "No blocked users")
    public static let SETTING_PRIVACY_AND_SECURITY = LocalizedString("setting_privacy_and_security", comment: "Privacy and Security")

    public static let SETTING_NOTIFICATION_MESSAGE = LocalizedString("setting_notification_message", comment: "MESSAGE NOTIFICATIONS")
    public static let SETTING_NOTIFICATION_MESSAGE_SUMMARY = LocalizedString("setting_notification_message_summary", comment: "You can set custom notifications for specific users on their Contact page.")
    public static let SETTING_NOTIFICATION_GROUP = LocalizedString("setting_notification_group", comment: "GROUP NOTIFICATIONS")
    public static let SETTING_NOTIFICATION_GROUP_SUMMARY = LocalizedString("setting_notification_group_summary", comment: "You can set custom notifications for specific groups on their Group Info page.")
    public static let SETTING_BLOCKED_USER_COUNT_SUFFIX = LocalizedString("setting_blocked_user_count_suffix", comment: " contacts")
    public static let SETTING_BLOCKED_USER_COUNT_NONE = LocalizedString("setting_blocked_user_count_none", comment: "None")
    public static let SETTING_ABOUT = LocalizedString("setting_about", comment: "About")
    public static let SETTING_PRIVACY_AND_SECURITY_SUMMARY = LocalizedString("setting_privacy_and_security_summary", comment: "Change who can add you to conversation and groups.")
    public static let SETTING_PRIVACY_AND_SECURITY_TITLE = LocalizedString("setting_privacy_and_security_title", comment: "PRIVACY")
    public static let SETTING_HEADER_MESSAGE_SOURCE = LocalizedString("setting_header_message_source", comment: "WHO CAN SEND ME MESSAGES")
    public static let SETTING_HEADER_CONVERSATION_SOURCE = LocalizedString("setting_header_conversation_source", comment: "WHO CAN ADD ME TO GROUP CHATS")
    public static let SETTING_STORAGE_USAGE = LocalizedString("setting_storage_usage", comment: "Storage Usage")
    public static func SETTING_STORAGE_USAGE_CLEAR(messageCount: Int, size: String) -> String {
    return String(format: LocalizedString("setting_storage_usage_clear", comment: "Clear %@ messages (%@)?"), "\(messageCount)", size)
    }
    public static let SETTING_LOGOUT = LocalizedString("setting_logout", comment: "Log Out")

    // Notifications
    public static let NOTIFICATION_REPLY = LocalizedString("notification_reply", comment: "Reply")
    public static let NOTIFICATION_MUTE = LocalizedString("notification_mute", comment: "Mute")
    public static let NOTIFICATION_CONTENT_PHOTO = LocalizedString("notification_content_photo", comment: "[Photo]")
    public static let NOTIFICATION_CONTENT_TRANSFER = LocalizedString("notification_content_transfer", comment: "[Transfer]")
    public static let NOTIFICATION_CONTENT_FILE = LocalizedString("notification_content_file", comment: "[File]")
    public static let NOTIFICATION_CONTENT_STICKER = LocalizedString("notification_content_sticker", comment: "[Sticker]")
    public static let NOTIFICATION_CONTENT_CONTACT = LocalizedString("notification_content_contact", comment: "[Contact]")
    public static let NOTIFICATION_CONTENT_DEPOSIT = LocalizedString("notification_content_deposit", comment: "[Deposit]")
    public static let NOTIFICATION_CONTENT_FEE = LocalizedString("notification_content_fee", comment: "[Fee]")
    public static let NOTIFICATION_CONTENT_WITHDRAWAL = LocalizedString("notification_content_withdrawal", comment: "[Withdrawal]")
    public static let NOTIFICATION_CONTENT_REBATE = LocalizedString("notification_content_rebate", comment: "[Rebate]")
    public static let NOTIFICATION_CONTENT_VIDEO = LocalizedString("notification_content_video", comment: "[Video]")
    public static let NOTIFICATION_CONTENT_AUDIO = LocalizedString("notification_content_audio", comment: "[Audio]")
    public static func ALERT_KEY_GROUP_MESSAGE(fullname: String) -> String {
        return String(format: LocalizedString("alert_key_group_message", comment: "%@ send a message"), fullname)
    }
    public static func ALERT_KEY_GROUP_TEXT_MESSAGE(fullname: String) -> String {
        return String(format: LocalizedString("alert_key_group_text_message", comment: "%@ send a message"), fullname)
    }
    public static func ALERT_KEY_GROUP_IMAGE_MESSAGE(fullname: String) -> String {
        return String(format: LocalizedString("alert_key_group_image_message", comment: "%@ send a photo"), fullname)
    }
    public static func ALERT_KEY_GROUP_VIDEO_MESSAGE(fullname: String) -> String {
        return String(format: LocalizedString("alert_key_group_video_message", comment: "%@ send a video"), fullname)
    }
    public static func ALERT_KEY_GROUP_DATA_MESSAGE(fullname: String) -> String {
        return String(format: LocalizedString("alert_key_group_data_message", comment: "%@ send a file"), fullname)
    }
    public static func ALERT_KEY_GROUP_STICKER_MESSAGE(fullname: String) -> String {
        return String(format: LocalizedString("alert_key_group_sticker_message", comment: "%@ send a sticker"), fullname)
    }
    public static func ALERT_KEY_GROUP_CONTACT_MESSAGE(fullname: String) -> String {
        return String(format: LocalizedString("alert_key_group_contact_message", comment: "%@ send a contact"), fullname)
    }
    public static func ALERT_KEY_GROUP_AUDIO_MESSAGE(fullname: String) -> String {
        return String(format: LocalizedString("alert_key_group_audio_message", comment: "%@ send a audio"), fullname)
    }
    public static let ALERT_KEY_CONTACT_MESSAGE = LocalizedString("alert_key_contact_message", comment: "send you a message")
    public static let ALERT_KEY_CONTACT_TEXT_MESSAGE = LocalizedString("alert_key_contact_text_message", comment: "send you a message")
    public static let ALERT_KEY_CONTACT_IMAGE_MESSAGE = LocalizedString("alert_key_contact_image_message", comment: "send you a photo")
    public static let ALERT_KEY_CONTACT_VIDEO_MESSAGE = LocalizedString("alert_key_contact_video_message", comment: "send you a video")
    public static let ALERT_KEY_CONTACT_TRANSFER_MESSAGE = LocalizedString("alert_key_contact_transfer_message", comment: "send you a transfer")
    public static let ALERT_KEY_CONTACT_DATA_MESSAGE = LocalizedString("alert_key_contact_data_message", comment: "send you a file")
    public static let ALERT_KEY_CONTACT_STICKER_MESSAGE = LocalizedString("alert_key_contact_sticker_message", comment: "send you a sticker")
    public static let ALERT_KEY_CONTACT_CONTACT_MESSAGE = LocalizedString("alert_key_contact_contact_message", comment: "send you a contact")
    public static let ALERT_KEY_CONTACT_AUDIO_MESSAGE = LocalizedString("alert_key_contact_audio_message", comment: "send you a audio")

    // About
    public static let ABOUT_LOGOUT_TITLE = LocalizedString("about_logout_title", comment: "Do you want to log out?")
    public static let ABOUT_LOGOUT_MESSAGE = LocalizedString("about_logout_message", comment: "All messages sent to you during the withdrawal will be discarded and can not be retrieved!")
    public static let ABOUT_LOGOUT_BUTTON = LocalizedString("about_logout_button", comment: "Log Out")

    public static let REPORT_TITLE = LocalizedString("report_title", comment: "Send the conversation log to developers?")
    public static let REPORT_BUTTON = LocalizedString("report_button", comment: "Send")
}
