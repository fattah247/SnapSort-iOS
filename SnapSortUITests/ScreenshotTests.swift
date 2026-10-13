//
//  ScreenshotTests.swift
//  SnapSortUITests
//
//  Walks through the app and saves the screenshots used in the README.
//  Run it through scripts/make-screenshots.sh, which prepares a fresh
//  simulator with the demo library; see docs/screenshots.md.
//

import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testCaptureReadmeScreenshots() throws {
        addUIInterruptionMonitor(withDescription: "Photo access") { alert in
            let allow = alert.buttons["Allow Full Access"]
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        app.launch()

        // Onboarding
        XCTAssertTrue(app.staticTexts["Hi, I'm Snappy!"].waitForExistence(timeout: 15))
        snap("onboarding")
        app.buttons["Continue"].tap()
        // Each page has its own Continue, so wait for the page itself first
        XCTAssertTrue(app.staticTexts["Can I take a peek?"].waitForExistence(timeout: 10))
        pause(1)
        app.buttons["Continue"].tap()
        // iOS asks for photo access here, and on a freshly filled library the
        // prompt can take a minute to show up. XCTest's own alert handling would
        // tap "Don't Allow", so the monitor above answers first; touching the app
        // is what gives it the chance to run.
        let nudge = app.staticTexts["Want a gentle nudge?"]
        let deadline = Date().addingTimeInterval(150)
        while !nudge.waitForExistence(timeout: 3), Date() < deadline {
            app.tap()
        }
        XCTAssertTrue(nudge.exists, "The photo access prompt was never answered")
        pause(1)
        app.buttons["Not Now"].tap()
        let letsGo = app.buttons["Let's Go"]
        if letsGo.waitForExistence(timeout: 5) { letsGo.tap() }

        // The deck
        let bookmark = app.buttons["deck-bookmark"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 15))
        pause(3)
        snap("review")

        // Sort a few photos so Stats and Trash have something to show
        for action in ["bookmark", "trash", "bookmark", "trash", "trash", "bookmark", "trash"] {
            tapWhenReady(app.buttons["deck-\(action)"])
            pause(0.8)
        }

        // Smart groups, once the library scan has finished
        app.buttons["Smart"].tap()
        let similar = app.buttons["smart-duplicates"]
        XCTAssertTrue(similar.waitForExistence(timeout: 20))
        // The row reads "Still looking" during the scan and shows a count once it's done
        let scanned = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@ AND value != %@", "Still looking", "0 photos"),
            object: similar
        )
        XCTAssertEqual(XCTWaiter.wait(for: [scanned], timeout: 600), .completed, "The library scan didn't finish")
        pause(2)
        snap("smart")

        similar.tap()
        XCTAssertTrue(app.navigationBars["Similar Shots"].waitForExistence(timeout: 10))
        let trashSet = app.buttons["similar-trash"].firstMatch
        XCTAssertTrue(trashSet.waitForExistence(timeout: 15))
        pause(2)
        snap("similar-shots")
        trashSet.tap()
        pause(1)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Library"].tap()

        for (tab, name) in [("Stats", "stats"), ("Trash", "trash"), ("Bookmarks", "bookmarks"), ("Settings", "settings")] {
            app.tabBars.buttons[tab].tap()
            pause(2)
            snap(name)
        }
        // The dark mode shot is taken by the script after this, since
        // switching the appearance from here doesn't reach the app
    }

    // MARK: - Helpers

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapWhenReady(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) never appeared")
        element.tap()
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
