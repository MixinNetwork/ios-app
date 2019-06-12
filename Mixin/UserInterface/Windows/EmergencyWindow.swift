import Foundation

class EmergencyWindow: BottomSheetView {



    @IBAction func nextAction(_ sender: Any) {
        CommonUserDefault.shared.isEmergencyTips = false

        // TODO
        dismissPopupControllerAnimated()
    }


    class func instance() -> EmergencyWindow {
        return Bundle.main.loadNibNamed("EmergencyWindow", owner: nil, options: nil)?.first as! EmergencyWindow
    }
}
