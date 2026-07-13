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
        // Default produksi idle-spotlight = false (hanya aktif di page tertentu).
        // Aktifkan di test agar jalur appearForIdle/looping bisa diuji.
        engine.setIdleAnimationEnabled(true)
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

    // MARK: - Spotlight Presence (AFK Appear / Tap Hide)

    // DEFAULT: kucing sembunyi (belum ada AFK / reaction)
    func testKucingDefaultSembunyi() {
        XCTAssertFalse(engine.isSpotlightPresent)
    }

    // User AFK → kucing muncul di spotlight (tengah layar) + looping rest state
    func testAfkMemunculkanKucingDiSpotlight() {
        engine.appearForIdle()

        XCTAssertTrue(engine.isSpotlightPresent)
        XCTAssertTrue(CatState.restPool.contains(engine.currentState))
        XCTAssertEqual(engine.catPositionX, engine.spotlightX, accuracy: 0.5)
        XCTAssertEqual(engine.catPositionY, engine.spotlightY, accuracy: 0.5)
    }

    // appearForIdle idempotent — sudah tampil tidak berubah posisi/present
    func testAppearForIdleTidakDobelSaatSudahTampil() {
        engine.appearForIdle()
        let stateWhileShown = engine.currentState
        engine.appearForIdle()
        XCTAssertTrue(engine.isSpotlightPresent)
        XCTAssertEqual(engine.currentState, stateWhileShown)
    }

    // Reaction (happy/sad/annoyed/exhausted) langsung tampil di spotlight
    func testReactionLangsungMunculDiSpotlight() {
        XCTAssertFalse(engine.isSpotlightPresent)

        engine.handleTransactionSuccess()

        XCTAssertEqual(engine.currentState, .happy)
        XCTAssertTrue(engine.isSpotlightPresent)
        XCTAssertEqual(engine.catPositionX, engine.spotlightX, accuracy: 0.5)
        XCTAssertEqual(engine.catPositionY, engine.spotlightY, accuracy: 0.5)
    }

    // Menyentuh layar di LUAR kucing → kucing sembunyi
    func testTapDiLuarKucingMenyembunyikan() {
        engine.appearForIdle()
        XCTAssertTrue(engine.isSpotlightPresent)

        engine.hideFromSpotlight()

        XCTAssertFalse(engine.isSpotlightPresent)
    }

    // Menyentuh kucing (isOnCat = true) → TIDAK menyembunyikan
    func testTapPadaKucingTidakMenyembunyikan() {
        engine.appearForIdle()
        engine.registerUserActivity(isOnCat: true)
        XCTAssertTrue(engine.isSpotlightPresent)
    }

    // Kucing dibuang (dismiss) → sembunyi & TIDAK muncul lagi via AFK
    func testDismissMenyembunyikanDanTidakMunculViaAfk() {
        engine.appearForIdle()
        engine.dismiss()

        XCTAssertTrue(engine.isDismissed)
        XCTAssertFalse(engine.isSpotlightPresent)

        // AFK tidak boleh memunculkan kucing yang sudah dibuang
        engine.appearForIdle()
        XCTAssertFalse(engine.isSpotlightPresent)
    }

    // MARK: - Stage Label ("Now Performing")

    // Kemunculan AFK → label "Now Performing" tampil
    func testLabelMunculSaatAfk() {
        engine.appearForIdle()
        XCTAssertTrue(engine.isStageLabelVisible)
    }

    // Reaction (dari sembunyi) → label TIDAK muncul (bukan performance idle)
    func testLabelTidakMunculSaatReaction() {
        engine.handleTransactionSuccess()
        XCTAssertTrue(engine.isSpotlightPresent)
        XCTAssertFalse(engine.isStageLabelVisible)
    }

    // Label sedang tampil lalu ada reaction → label langsung hilang
    func testLabelHilangSaatReaction() {
        engine.appearForIdle()
        XCTAssertTrue(engine.isStageLabelVisible)
        engine.handleTransactionSuccess()
        XCTAssertFalse(engine.isStageLabelVisible)
    }

    // Kucing sembunyi → label ikut hilang
    func testLabelHilangSaatKucingSembunyi() {
        engine.appearForIdle()
        engine.hideFromSpotlight()
        XCTAssertFalse(engine.isStageLabelVisible)
    }

    // MARK: - Spotlight Idle Enable / Disable

    // Default engine mengikuti feature flag (produksi: false = off)
    func testDefaultIdleMengikutiFeatureFlag() {
        let fresh = CatBehaviorEngine()
        XCTAssertEqual(
            fresh.isIdleAnimationEnabled,
            CatFeatureFlags.idleAnimationEnabledByDefault
        )
        fresh.cleanup()
    }

    // Idle-spotlight nonaktif → AFK TIDAK memunculkan kucing
    func testIdleDisabledTidakMunculViaAfk() {
        engine.setIdleAnimationEnabled(false)
        engine.appearForIdle()
        XCTAssertFalse(engine.isSpotlightPresent)
    }

    // Menonaktifkan saat sedang looping → kucing langsung sembunyi
    func testDisableSaatLoopingMenyembunyikan() {
        engine.appearForIdle()
        XCTAssertTrue(engine.isSpotlightPresent)

        engine.setIdleAnimationEnabled(false)
        XCTAssertFalse(engine.isSpotlightPresent)
    }

    // Idle nonaktif TAPI reaction tetap muncul (transaksi sukses)
    func testReactionTetapMunculWalauIdleDisabled() {
        engine.setIdleAnimationEnabled(false)
        engine.handleTransactionSuccess()
        XCTAssertEqual(engine.currentState, .happy)
        XCTAssertTrue(engine.isSpotlightPresent)
    }

    // Idle nonaktif: reaction selesai (animationFinished) → kucing sembunyi,
    // tidak lanjut looping exercise
    func testReactionSelesaiMenyembunyikanSaatIdleDisabled() {
        engine.setIdleAnimationEnabled(false)
        engine.handleTransactionSuccess()
        XCTAssertTrue(engine.isSpotlightPresent)

        engine.processEvent(.animationFinished)

        XCTAssertTrue(CatState.restPool.contains(engine.currentState))
        XCTAssertFalse(engine.isSpotlightPresent)
    }

    // bringBack (shake) → muncul lagi di spotlight (tengah), bukan pojok
    func testBringBackMunculDiSpotlight() {
        engine.dismiss()
        engine.bringBack()

        XCTAssertFalse(engine.isDismissed)
        XCTAssertTrue(engine.isSpotlightPresent)
        XCTAssertTrue(CatState.restPool.contains(engine.currentState))
        XCTAssertEqual(engine.catPositionX, engine.spotlightX, accuracy: 0.5)
        XCTAssertEqual(engine.catPositionY, engine.spotlightY, accuracy: 0.5)
    }
}
