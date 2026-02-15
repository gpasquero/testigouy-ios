import XCTest
@testable import TestigoUY

final class TestigoUYTests: XCTestCase {

    func testCameraRTSPURL() {
        let camera = Camera(
            name: "Test Camera",
            host: "192.168.1.100",
            rtspPort: 554,
            rtspPath: "/stream1",
            username: "admin",
            password: "pass123"
        )

        let url = camera.rtspURL
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "rtsp")
        XCTAssertEqual(url?.host, "192.168.1.100")
        XCTAssertEqual(url?.port, 554)
        XCTAssertEqual(url?.path, "/stream1")
        XCTAssertEqual(url?.user, "admin")
    }

    func testCameraRTSPURLWithoutCredentials() {
        let camera = Camera(
            name: "Public Camera",
            host: "192.168.1.50",
            rtspPort: 8554,
            rtspPath: "/live"
        )

        let url = camera.rtspURL
        XCTAssertNotNil(url)
        XCTAssertNil(url?.user)
        XCTAssertEqual(url?.port, 8554)
    }

    func testRTSPURLValidator() {
        XCTAssertTrue(RTSPURLValidator.isValidHost("192.168.1.1"))
        XCTAssertTrue(RTSPURLValidator.isValidHost("10.0.0.1"))
        XCTAssertTrue(RTSPURLValidator.isValidHost("camera.local"))
        XCTAssertFalse(RTSPURLValidator.isValidHost(""))
        XCTAssertFalse(RTSPURLValidator.isValidHost("999.999.999.999"))

        XCTAssertTrue(RTSPURLValidator.isValidPort(554))
        XCTAssertTrue(RTSPURLValidator.isValidPort(8554))
        XCTAssertFalse(RTSPURLValidator.isValidPort(0))
        XCTAssertFalse(RTSPURLValidator.isValidPort(70000))
    }

    func testGridLayout() {
        XCTAssertEqual(GridLayout.single.columns, 1)
        XCTAssertEqual(GridLayout.single.maxCameras, 1)
        XCTAssertEqual(GridLayout.twoByTwo.columns, 2)
        XCTAssertEqual(GridLayout.twoByTwo.maxCameras, 4)
        XCTAssertEqual(GridLayout.threeByThree.columns, 3)
        XCTAssertEqual(GridLayout.threeByThree.maxCameras, 9)
    }

    func testStreamState() {
        XCTAssertFalse(StreamState.idle.isActive)
        XCTAssertFalse(StreamState.connecting.isActive)
        XCTAssertTrue(StreamState.playing.isActive)
        XCTAssertTrue(StreamState.recording.isActive)
        XCTAssertFalse(StreamState.error("test").isActive)
    }

    func testRecordingFormattedDuration() {
        let now = Date()
        let recording = Recording(
            cameraId: UUID(),
            cameraName: "Test",
            filePath: "/test.mp4",
            startDate: now,
            endDate: now.addingTimeInterval(125),
            fileSize: 1024 * 1024 * 50
        )
        XCTAssertEqual(recording.formattedDuration, "02:05")
    }

    func testPersistenceController() {
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.container)

        // Test camera save and fetch
        let camera = Camera(
            name: "Test Camera",
            host: "192.168.1.100",
            rtspPort: 554,
            rtspPath: "/stream1"
        )
        controller.saveCamera(camera)
        let cameras = controller.fetchCameras()
        XCTAssertEqual(cameras.count, 1)
        XCTAssertEqual(cameras.first?.name, "Test Camera")

        // Test camera delete
        controller.deleteCamera(id: camera.id)
        XCTAssertEqual(controller.fetchCameras().count, 0)
    }
}
