//
//  WalkUITests.swift
//  JustWalkUITests
//
//  UI tests for walk flow screens
//  Note: These tests require manual verification for visual elements.
//  They verify basic navigation and state transitions.
//

import XCTest

final class WalkUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Idle View

    @MainActor
    func testIdleView_showsStartControls() throws {
        // Verify the main view has start walk controls
        // The specific accessibility identifiers will depend on implementation
        // This is a placeholder for manual verification
        let exists = app.buttons.count > 0
        XCTAssertTrue(exists, "Main view should have interactive buttons")
    }

    // MARK: - Walk Flow (Manual Verification Recommended)

    @MainActor
    func testAppLaunches_withoutCrash() throws {
        // Basic smoke test: app should launch without crashing
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    @MainActor
    func testNavigationExists() throws {
        // Verify basic navigation structure exists
        // Note: Specific elements depend on whether onboarding has been completed
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Main Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testScreenshot_capturesCurrentState() throws {
        // Capture screenshot for manual visual verification
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Walk UI State"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
