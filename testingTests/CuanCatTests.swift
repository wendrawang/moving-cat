import XCTest
@testable import testing

// MARK: - CuanCat Unit Tests
//
// CATATAN: project belum punya test target. Untuk menjalankan:
//   Xcode → File → New → Target → Unit Testing Bundle ("testingTests"),
//   lalu tambahkan folder testingTests/ ke target tersebut.

final class CatStateRestPoolTests: XCTestCase {

    // randomRest() harus selalu menghasilkan salah satu dari 3 state exercise
    func testRandomRestSelaluDariRestPool() {
        for _ in 0..<50 {
            let picked = CatState.randomRest()
            XCTAssertTrue(CatState.restPool.contains(picked))
        }
    }

    func testRestPoolBerisiTigaExercise() {
        XCTAssertEqual(CatState.restPool, [.warmup, .pushup, .starJump])
        // idle TIDAK boleh ada di pool — legacy state, tidak muncul lagi
        XCTAssertFalse(CatState.restPool.contains(.idle))
    }

    // isRestState: rest pool + idle legacy = true, lainnya false
    func testIsRestState() {
        XCTAssertTrue(CatState.idle.isRestState)
        XCTAssertTrue(CatState.warmup.isRestState)
        XCTAssertTrue(CatState.pushup.isRestState)
        XCTAssertTrue(CatState.starJump.isRestState)
        XCTAssertFalse(CatState.walking.isRestState)
        XCTAssertFalse(CatState.happy.isRestState)
    }

    // Mapping state → animasi exercise harus 1:1 dan loop
    func testRestStateAnimationMapping() {
        XCTAssertEqual(CatState.warmup.animationType, .warmup)
        XCTAssertEqual(CatState.pushup.animationType, .pushup)
        XCTAssertEqual(CatState.starJump.animationType, .starJump)
        XCTAssertTrue(CatAnimationType.warmup.loops)
        XCTAssertTrue(CatAnimationType.pushup.loops)
        XCTAssertTrue(CatAnimationType.starJump.loops)
    }
}

final class CatAssetManifestTests: XCTestCase {

    func testAssetNameAnimasiExercise() {
        XCTAssertEqual(CatAssetManifest.assetName(animation: .warmup), "cat_warmup")
        XCTAssertEqual(CatAssetManifest.assetName(animation: .pushup), "cat_pushup")
        XCTAssertEqual(CatAssetManifest.assetName(animation: .starJump), "cat_starjump")
    }
}

final class CatStateMachineTests: XCTestCase {

    // reportError → event transactionFailed → state annoyed
    func testEventTransactionFailedMenjadiAnnoyed() {
        let machine = CatStateMachine()
        let result = machine.transition(event: .transactionFailed)
        XCTAssertEqual(result?.newState, .annoyed)
    }

    // transactionFailed() → event transactionFailedSad → state sad
    func testEventTransactionFailedSadMenjadiSad() {
        let machine = CatStateMachine()
        let result = machine.transition(event: .transactionFailedSad)
        XCTAssertEqual(result?.newState, .sad)
    }

    // Transient selesai → kembali ke rest via restStateProvider (injectable)
    func testAnimationFinishedKembaliKeRestState() {
        let machine = CatStateMachine()
        machine.restStateProvider = { .pushup }
        machine.applyTransition(
            CatTransitionResult(newState: .sad, sideEffects: [])
        )
        let result = machine.transition(event: .animationFinished)
        XCTAssertEqual(result?.newState, .pushup)
    }

    // Shuffle-bag: state awal + 2 rotasi pertama = KETIGA exercise muncul semua
    // (bukan random murni yang bisa bolak-balik 2 animasi saja)
    func testRotasiMenampilkanSemuaTigaExercise() {
        let machine = CatStateMachine()
        machine.applyTransition(
            CatTransitionResult(newState: machine.nextRestState(), sideEffects: [])
        )
        var seen: Set<CatState> = [machine.currentState]
        for _ in 0..<2 {
            guard let result = machine.transition(
                event: .idleTimerTick(CatTimingConstants.restRotationInterval)
            ) else {
                XCTFail("Transisi rotasi tidak boleh nil dari rest state")
                return
            }
            machine.applyTransition(result)
            seen.insert(result.newState)
        }
        XCTAssertEqual(seen, Set(CatState.restPool))
    }

    // Rotasi tidak pernah menampilkan exercise yang sama dua kali berurutan,
    // termasuk di sambungan antar ronde shuffle
    func testRotasiTidakPernahRepeatBerurutan() {
        let machine = CatStateMachine()
        machine.applyTransition(
            CatTransitionResult(newState: machine.nextRestState(), sideEffects: [])
        )
        var previous = machine.currentState
        for _ in 0..<30 {
            guard let result = machine.transition(
                event: .idleTimerTick(CatTimingConstants.restRotationInterval)
            ) else {
                XCTFail("Transisi rotasi tidak boleh nil dari rest state")
                return
            }
            XCTAssertNotEqual(result.newState, previous)
            machine.applyTransition(result)
            previous = result.newState
        }
    }

    // randomRest(excluding:) tidak pernah mengembalikan state yang dikecualikan
    func testRandomRestExcludingTidakSamaDenganSekarang() {
        for _ in 0..<30 {
            XCTAssertNotEqual(CatState.randomRest(excluding: .pushup), .pushup)
        }
    }

    // Rest state (exercise) + idle tick lama → walking (saat walking enabled)
    func testRestStateBisaTransisiKeWalking() {
        let machine = CatStateMachine()
        machine.applyTransition(
            CatTransitionResult(newState: .warmup, sideEffects: [])
        )
        let result = machine.transition(
            event: .idleTimerTick(CatTimingConstants.idleToWalkThreshold)
        )
        XCTAssertEqual(result?.newState, .walking)
    }
}
