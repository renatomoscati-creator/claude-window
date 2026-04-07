import XCTest
@testable import ClaudeWindow

final class SettingsStoreTests: XCTestCase {

    var store: SettingsStore!

    override func setUp() {
        super.setUp()
        store = SettingsStore(suiteName: "com.claudewindow.tests.\(UUID().uuidString)")
    }

    func test_defaultPlan_isPro() {
        XCTAssertEqual(store.plan, .pro)
    }

    func test_defaultSurface_isDesktop() {
        XCTAssertEqual(store.primarySurface, .desktop)
    }

    func test_savePlan_persists() {
        store.plan = .max
        XCTAssertEqual(store.plan, .max)
    }

    func test_saveWorkloadProfile_persists() {
        store.workloadProfile = .coding
        XCTAssertEqual(store.workloadProfile, .coding)
    }

    func test_saveMode_persists() {
        store.operatingMode = .reliability
        XCTAssertEqual(store.operatingMode, .reliability)
    }

    func test_defaultRefreshInterval_isReasonable() {
        XCTAssertGreaterThanOrEqual(store.refreshIntervalSeconds, 60)
        XCTAssertLessThanOrEqual(store.refreshIntervalSeconds, 3600)
    }
}
