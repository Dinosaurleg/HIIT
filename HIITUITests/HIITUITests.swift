//
//  HIITUITests.swift
//  HIITUITests
//
//  Created by Jemin Shin on 4/17/25.
//

import XCTest

final class HIITUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testCreateTimerAndPersistAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add Timer"].tap()

        let save = app.buttons["timer.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)

        let name = "HIIT \(UUID().uuidString.prefix(8))"
        enterText(in: app.textFields["timer.name"], with: name, app: app)
        XCTAssertTrue(save.isEnabled)

        replaceText(in: app.textFields["timer.workPeriod.seconds"], with: "90", app: app)
        replaceText(in: app.textFields["timer.restPeriod.seconds"], with: "1", app: app)
        XCTAssertTrue(save.isEnabled)
        save.tap()

        scrollToElement(app.staticTexts[name], app: app)
        XCTAssertTrue(app.staticTexts["1:30 work / 0:01 rest / 8 rounds"].exists)

        app.terminate()
        app.launch()
        scrollToElement(app.staticTexts[name], app: app)
        app.staticTexts[name].tap()
        XCTAssertTrue(app.staticTexts["Work, 1:30"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTimerCanStartPauseAndReset() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add Timer"].tap()

        let name = "Timer \(UUID().uuidString.prefix(8))"
        let nameField = app.textFields["timer.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        enterText(in: nameField, with: name, app: app)
        app.buttons["timer.save"].tap()

        let timerRow = app.staticTexts[name]
        scrollToElement(timerRow, app: app)
        timerRow.tap()
        app.buttons["timer.startWorkout"].tap()

        XCTAssertTrue(app.staticTexts["Warm-up"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["00:30"].exists)

        let startPauseButton = app.buttons["timer.startPause"]
        startPauseButton.tap()
        XCTAssertEqual(startPauseButton.label, "Pause")
        startPauseButton.tap()
        XCTAssertEqual(startPauseButton.label, "Resume")

        app.buttons["timer.reset"].tap()
        XCTAssertEqual(startPauseButton.label, "Start")
        XCTAssertTrue(app.staticTexts["00:30"].exists)
    }

    @MainActor
    func testCancelDoesNotCreateTimer() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add Timer"].tap()

        let name = "Cancelled \(UUID().uuidString.prefix(8))"
        let nameField = app.textFields["timer.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        enterText(in: nameField, with: name, app: app)
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts[name].exists)
    }

    @MainActor
    func testListPlayAndInlineEditing() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add Timer"].tap()

        let name = "Edit \(UUID().uuidString.prefix(8))"
        let renamed = "Updated \(UUID().uuidString.prefix(8))"
        let nameField = app.textFields["timer.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        enterText(in: nameField, with: name, app: app)
        app.buttons["timer.save"].tap()

        let play = app.buttons["Play \(name)"]
        scrollToElement(play, app: app)
        play.tap()
        XCTAssertEqual(app.buttons["timer.startPause"].label, "Pause")
        app.buttons["Done"].tap()

        app.staticTexts[name].tap()
        XCTAssertTrue(app.buttons["timer.startWorkout"].waitForExistence(timeout: 5))
        app.buttons["Edit"].tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(app.sheets.count, 0)
        replaceText(in: nameField, with: renamed, app: app)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))

        app.buttons["Edit"].tap()
        replaceText(in: nameField, with: renamed, app: app)
        let countdown = app.switches["timer.countdownSound"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        XCTAssertEqual(countdown.value as? String, "1")
        app.swipeUp()
        countdown.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(countdown.value as? String, "0", countdown.debugDescription)
        app.buttons["timer.save"].tap()
        XCTAssertTrue(app.navigationBars[renamed].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Countdown sound, Off"].exists, app.debugDescription)

        app.terminate()
        app.launch()
        scrollToElement(app.staticTexts[renamed], app: app)
        app.staticTexts[renamed].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Countdown sound, Off"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testSwipeDeletesTimer() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add Timer"].tap()
        let name = "Delete \(UUID().uuidString.prefix(8))"
        let nameField = app.textFields["timer.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        enterText(in: nameField, with: name, app: app)
        app.buttons["timer.save"].tap()

        let row = app.staticTexts[name]
        scrollToElement(row, app: app)
        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertFalse(row.exists)
        app.terminate()
        app.launch()
        XCTAssertFalse(app.staticTexts[name].exists)
    }

    private func enterText(in textField: XCUIElement, with value: String, app: XCUIApplication) {
        textField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        textField.typeText(value)
    }

    private func scrollToElement(_ element: XCUIElement, app: XCUIApplication) {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        for _ in 0..<20 {
            if element.exists && element.isHittable {
                return
            }
            list.swipeUp()
        }
        XCTFail("Could not find \(element)")
    }

    private func replaceText(in textField: XCUIElement, with value: String, app: XCUIApplication) {
        textField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let currentValue = textField.value as? String ?? ""
        textField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count) + value)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
