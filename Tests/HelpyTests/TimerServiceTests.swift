import XCTest
@testable import Helpy

@MainActor
final class TimerServiceTests: XCTestCase {
    private var timerService: TimerService!
    private var estimateStore: EstimateStore!
    
    override func setUp() {
        super.setUp()
        timerService = TimerService()
        estimateStore = EstimateStore()
        timerService.estimateStore = estimateStore
    }
    
    override func tearDown() {
        timerService.stopTimer()
        timerService = nil
        estimateStore = nil
        super.tearDown()
    }
    
    func testStartTimerWithZeroDurationUsesStopwatchMode() {
        timerService.startTimer(reminderId: "task-1", duration: 0)
        
        XCTAssertEqual(timerService.state, .running)
        XCTAssertEqual(timerService.activeReminderId, "task-1")
        XCTAssertTrue(timerService.isStopwatch)
        XCTAssertFalse(timerService.isOnBreak)
    }
    
    func testBreakRoundTripRestoresTask() {
        timerService.startTimer(reminderId: "task-2", duration: 1500)
        timerService.startBreak(duration: 60)
        
        XCTAssertEqual(timerService.state, .running)
        XCTAssertTrue(timerService.isOnBreak)
        XCTAssertNil(timerService.activeReminderId)
        XCTAssertEqual(timerService.initialDuration, 60)
        
        timerService.endBreak()
        
        XCTAssertEqual(timerService.state, .running)
        XCTAssertFalse(timerService.isOnBreak)
        XCTAssertEqual(timerService.activeReminderId, "task-2")
    }
    
    func testStopTimerResetsState() {
        timerService.startTimer(reminderId: "task-3", duration: 600)
        timerService.startBreak(duration: 30)
        timerService.stopTimer()
        
        XCTAssertEqual(timerService.state, .stopped)
        XCTAssertNil(timerService.activeReminderId)
        XCTAssertFalse(timerService.isOnBreak)
        XCTAssertFalse(timerService.isOvertime)
        XCTAssertFalse(timerService.timesUpTriggered)
        XCTAssertEqual(timerService.remainingTime, 0, accuracy: 0.001)
    }
}
