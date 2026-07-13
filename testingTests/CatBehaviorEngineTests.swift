import XCTest
@testable import testing

// MARK: - CatBehaviorEngine Unit Tests
//
// CATATAN: project belum punya test target. Untuk menjalankan:
//   Xcode → File → New → Target → Unit Testing Bundle ("testingTests"),
//   lalu tambahkan folder testingTests/ ke target tersebut.

final class CatBehaviorEngineTests: XCTestCase {

    private var engine: CatBehaviorEngine!

    override func setUp() {
        super.setUp()
        engine = CatBehaviorEngine()
    }

    override func tearDown() {
        engine.cleanup()
        engine = nil
        super.tearDown()
    }

    // State AWAL harus langsung random dari rest pool — BUKAN idle
    func testStateAwalDariRestPoolBukanIdle() {
        XCTAssertTrue(CatState.restPool.contains(engine.currentState))
        XCTAssertNotEqual(engine.currentState, .idle)
        // State machine harus sync dengan state awal engine
        XCTAssertEqual(engine.stateMachine.currentState, engine.currentState)
        // Animasi yang dirender = animasi exercise dari state tersebut
        XCTAssertEqual(engine.displayAnimation, engine.currentState.animationType)
    }

    // Auto-walking harus nonaktif by default (CatFeatureFlags)
    func testAutoWalkingNonaktifByDefault() {
        XCTAssertFalse(engine.isWalkingEnabled)
    }

    // setWalkingEnabled(true) TIDAK bisa menyalakan walking selama flag mati —
    // ini yang dulu bocor lewat ContentView.onAppear
    func testSetWalkingEnabledDikunciFeatureFlag() {
        engine.setWalkingEnabled(true)
        XCTAssertEqual(engine.isWalkingEnabled, CatFeatureFlags.autoWalkingEnabled)
    }

    // transactionFailed() → animasi sad
    func testHandleTransactionFailedMenjadiSad() {
        engine.handleTransactionFailed()
        XCTAssertEqual(engine.currentState, .sad)
        XCTAssertEqual(engine.displayAnimation, .sad)
    }

    // reportError(_:) → animasi annoyed
    func testHandleTransactionErrorMenjadiAnnoyed() {
        engine.handleTransactionError(.serverError)
        XCTAssertEqual(engine.currentState, .annoyed)
        XCTAssertEqual(engine.displayAnimation, .annoyed)
    }

    // Drag lepas di tengah layar → posisi di-commit + homebase ikut pindah
    func testDragEndedCommitPosisiBaru() {
        let startX = engine.catPositionX
        let startY = engine.catPositionY
        let translation = CGSize(width: -100, height: -150)

        engine.handleDragChanged(translation: translation)
        engine.handleDragEnded(translation: translation)

        XCTAssertFalse(engine.isDismissed)
        XCTAssertEqual(engine.catPositionX, startX - 100, accuracy: 0.5)
        XCTAssertEqual(engine.catPositionY, startY - 150, accuracy: 0.5)
        XCTAssertEqual(engine.homePositionX, engine.catPositionX, accuracy: 0.5)
        XCTAssertEqual(engine.dragOffsetX, 0)
        XCTAssertEqual(engine.dragOffsetY, 0)
    }

    // Drag lepas dekat tepi layar → kucing dibuang (dismiss)
    func testDragKeTepiLayarTetapDismiss() {
        let translation = CGSize(width: engine.screenWidth, height: 0)
        engine.handleDragChanged(translation: translation)
        XCTAssertTrue(engine.isDismissed)
    }

    // MARK: - Spotlight

    // Reaction (happy/sad/annoyed/exhausted) langsung tampil di spotlight
    // (tengah layar) sejak muncul
    func testReactionLangsungMunculDiSpotlight() {
        XCTAssertNotEqual(engine.catPositionX, engine.spotlightX, accuracy: 0.5)

        engine.handleTransactionSuccess()

        XCTAssertEqual(engine.currentState, .happy)
        XCTAssertEqual(engine.catPositionX, engine.spotlightX, accuracy: 0.5)
        XCTAssertEqual(engine.catPositionY, engine.spotlightY, accuracy: 0.5)
    }

    // Rest state tanpa kegiatan → glide ke spotlight setelah threshold.
    // Homebase ikut pindah ke spotlight.
    func testRestTanpaKegiatanGlideKeSpotlight() {
        XCTAssertNotEqual(engine.catPositionX, engine.spotlightX, accuracy: 0.5)

        engine.glideToSpotlightIfIdle(
            elapsed: CatTimingConstants.idleToSpotlightThreshold
        )

        XCTAssertEqual(engine.catPositionX, engine.spotlightX, accuracy: 0.5)
        XCTAssertEqual(engine.catPositionY, engine.spotlightY, accuracy: 0.5)
        XCTAssertEqual(engine.homePositionX, engine.spotlightX, accuracy: 0.5)
        XCTAssertEqual(engine.homePositionY, engine.spotlightY, accuracy: 0.5)
    }

    // Belum melewati threshold → tetap di posisi semula
    func testGlideTidakJalanSebelumThreshold() {
        let startX = engine.catPositionX
        engine.glideToSpotlightIfIdle(
            elapsed: CatTimingConstants.idleToSpotlightThreshold - 1
        )
        XCTAssertEqual(engine.catPositionX, startX, accuracy: 0.5)
    }

    // Sedang loading = ada kegiatan → tidak glide ke spotlight
    func testGlideTidakJalanSaatLoading() {
        let startX = engine.catPositionX
        engine.handleLoadingStarted(.silent)
        engine.glideToSpotlightIfIdle(
            elapsed: CatTimingConstants.idleToSpotlightThreshold
        )
        XCTAssertEqual(engine.catPositionX, startX, accuracy: 0.5)
    }

    // Kucing dibuang (dismiss) → tidak glide ke spotlight
    func testGlideTidakJalanSaatDismissed() {
        engine.dismiss()
        let startX = engine.catPositionX
        engine.glideToSpotlightIfIdle(
            elapsed: CatTimingConstants.idleToSpotlightThreshold
        )
        XCTAssertEqual(engine.catPositionX, startX, accuracy: 0.5)
    }

    // bringBack → langsung muncul di homebase kanan-bawah dengan rest state acak
    func testBringBackInstanDiHomebaseKananBawah() {
        engine.dismiss()
        engine.bringBack()

        let expectedX = engine.screenWidth * CatLayoutConstants.defaultStartXRatio
        let expectedY = engine.screenHeight - CatLayoutConstants.bottomPadding

        XCTAssertFalse(engine.isDismissed)
        XCTAssertTrue(CatState.restPool.contains(engine.currentState))
        XCTAssertEqual(engine.catPositionX, expectedX, accuracy: 0.5)
        XCTAssertEqual(engine.catPositionY, expectedY, accuracy: 0.5)
    }
}
