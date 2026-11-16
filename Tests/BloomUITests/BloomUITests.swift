import XCTest

final class BloomUITests: XCTestCase {
    @MainActor
    func testTimestampedLoggingAndOneOffCreation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
        app.buttons["habit-Drink water"].tap()
        XCTAssertTrue(app.buttons["add-one"].waitForExistence(timeout: 5))
        app.buttons["add-one"].tap()
        app.buttons["add-one"].tap()
        XCTAssertEqual(app.staticTexts["habit-count"].label, "2")
        XCTAssertTrue(app.staticTexts["2 entries"].exists)
        app.buttons["Log amount and time"].tap()
        let amount = app.textFields["log-amount"]
        amount.doubleTap()
        if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        amount.typeText("3")
        XCTAssertEqual(amount.value as? String, "3")
        app.buttons["save-entry"].tap()
        XCTAssertEqual(app.staticTexts["habit-count"].label, "5")
        app.buttons["Close habit"].tap()
        app.buttons["Add habit"].tap()
        app.buttons["schedule-type"].tap()
        app.buttons["One time"].tap()
        let name = app.textFields["habit-name"]
        name.tap(); name.typeText("Collected parcel")
        app.buttons["save-habit"].tap()
        let item = app.buttons["habit-Collected parcel"]
        app.swipeUp()
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        app.buttons["add-one"].tap()
        XCTAssertEqual(app.staticTexts["habit-count"].label, "2")
        app.buttons["Close habit"].tap()
        // Keep the comparison inside the visible Monday–Sunday week.
        let offset = Calendar.current.component(.weekday, from: Date()) == 1 ? -1 : 1
        let otherDay = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
        app.buttons[otherDay.formatted(date: .complete, time: .omitted)].tap()
        let absent = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["habit-Collected parcel"])
        XCTAssertEqual(XCTWaiter.wait(for: [absent], timeout: 5), .completed)
        app.buttons[Date().formatted(date: .complete, time: .omitted)].tap()
        app.buttons["All activity timeline"].tap()
        XCTAssertTrue(app.staticTexts["Collected parcel"].exists)
        XCTAssertTrue(app.staticTexts["Drink water"].exists)
        app.buttons["Done"].tap()
        app.buttons["Progress tab"].tap()
        XCTAssertTrue(app.staticTexts["Monthly rate"].exists)
        app.buttons["Report tab"].tap()
        XCTAssertTrue(app.staticTexts["Habit Tracker"].exists)
        app.buttons["Settings tab"].tap()
        XCTAssertTrue(app.buttons["Export backup"].exists)
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["habit-Drink water"].tap()
        XCTAssertEqual(app.staticTexts["habit-count"].label, "5")
    }

    @MainActor
    func testFutureOneTimeTaskHasNoPrematureCheckIn() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
        app.buttons["Add habit"].tap()
        app.buttons["schedule-type"].tap()
        app.buttons["One time"].tap()
        app.buttons["due-tomorrow"].tap()
        XCTAssertFalse(app.switches["Record first check-in"].exists)
        let name = app.textFields["habit-name"]
        name.tap(); name.typeText("Future appointment")
        app.buttons["save-habit"].tap()
        XCTAssertFalse(app.buttons["habit-Future appointment"].exists)
        app.buttons["Upcoming tasks"].tap()
        let upcoming = app.buttons["upcoming-Future appointment"]
        XCTAssertTrue(upcoming.waitForExistence(timeout: 5)); upcoming.tap()
        XCTAssertEqual(app.staticTexts["habit-count"].label, "0")
        XCTAssertFalse(app.buttons["add-one"].isEnabled)
        app.buttons["Close habit"].tap()
        app.buttons["Done"].tap()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        if Calendar.current.component(.weekday, from: Date()) != 1 {
            app.buttons[tomorrow.formatted(date: .complete, time: .omitted)].tap()
            XCTAssertTrue(app.buttons["habit-Future appointment"].waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testIntervalScheduleCanBeCreatedEditedAndReloaded() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
        app.buttons["Add habit"].tap()
        app.buttons["schedule-type"].tap()
        app.buttons["Every X days"].tap()
        let interval = app.textFields["interval-days"]
        interval.doubleTap()
        if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        interval.typeText("730")
        XCTAssertEqual(interval.value as? String, "730")
        app.buttons["due-tomorrow"].tap()
        let name = app.textFields["habit-name"]
        name.tap(); name.typeText("Interval task")
        app.buttons["save-habit"].tap()
        app.buttons["Upcoming tasks"].tap()
        app.buttons["upcoming-Interval task"].tap()
        XCTAssertTrue(app.staticTexts["Every 730 days"].exists)
        app.buttons["Item options"].tap()
        app.buttons["Edit item"].tap()
        XCTAssertEqual(app.textFields["interval-days"].value as? String, "730")
        app.textFields["interval-days"].doubleTap()
        if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        app.textFields["interval-days"].typeText("7")
        app.buttons["save-habit"].tap()
        XCTAssertTrue(app.staticTexts["Every 7 days"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["Upcoming tasks"].tap()
        app.buttons["upcoming-Interval task"].tap()
        XCTAssertTrue(app.staticTexts["Every 7 days"].exists)
    }
}
