import XCTest

final class OpenInBrowserBridgeUITests: XCTestCase {
    func testJavaScriptOpenInBrowserPostsURLToNativeBridge() {
        let app = XCUIApplication()
        app.launchArguments = [OpenInBrowserBridgeUITestHarness.launchArgument]
        app.launchEnvironment[OpenInBrowserBridgeUITestHarness.urlEnvironmentKey] = "https://mixin.one/pay"
        app.launch()

        let result = app.staticTexts[OpenInBrowserBridgeUITestHarness.resultIdentifier]
        XCTAssertTrue(result.waitForExistence(timeout: 10))

        let predicate = NSPredicate(format: "label == %@", "https://mixin.one/pay")
        expectation(for: predicate, evaluatedWith: result)
        waitForExpectations(timeout: 10)
    }
}

private enum OpenInBrowserBridgeUITestHarness {
    static let launchArgument = "--open-in-browser-bridge-ui-test"
    static let urlEnvironmentKey = "OPEN_IN_BROWSER_BRIDGE_URL"
    static let resultIdentifier = "openInBrowserBridgeResult"
}
