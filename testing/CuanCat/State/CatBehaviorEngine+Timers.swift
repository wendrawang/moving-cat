import Combine
import Foundation

// MARK: - Timer Management

extension CatBehaviorEngine {

    // MARK: - Idle Timer

    func startIdleTimer() {
        idleElapsedSeconds = 0
        idleTimerCancellable?.cancel()
        idleTimerCancellable = Timer.publish(
            every: CatTimingConstants.idleTickInterval,
            on: .main, in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            guard let self = self else { return }
            self.idleElapsedSeconds += CatTimingConstants.idleTickInterval
            if !self.isWalkingEnabled,
                self.idleElapsedSeconds >= CatTimingConstants.idleToWalkThreshold {
                self.idleElapsedSeconds = 0
                return
            }
            self.processEvent(.idleTimerTick(self.idleElapsedSeconds))
        }
    }

    func stopIdleTimer() {
        idleTimerCancellable?.cancel()
        idleTimerCancellable = nil
        idleElapsedSeconds = 0
    }

    // MARK: - Loading Timer

    func startLoadingTimer() {
        loadingElapsedSeconds = 0
        currentRequestPatience = 100   // reset patience untuk request ini
        patienceApplied = false
        loadingTimerCancellable?.cancel()
        loadingTimerCancellable = Timer.publish(
            every: CatTimingConstants.loadingTickInterval,
            on: .main, in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            guard let self = self else { return }
            self.loadingElapsedSeconds += CatTimingConstants.loadingTickInterval

            // Decay patience progresif sesuai elapsed time
            let decay = CatStressConstants.patienceDecayPerTick(
                elapsed: self.loadingElapsedSeconds
            )
            self.currentRequestPatience = max(
                0, self.currentRequestPatience - decay
            )

            self.processEvent(.loadingTimerTick(self.loadingElapsedSeconds))
        }
    }

    func stopLoadingTimer() {
        loadingTimerCancellable?.cancel()
        loadingTimerCancellable = nil
        loadingElapsedSeconds = 0
    }

    // MARK: - Animation End Scheduler

    func scheduleAnimationEnd(after duration: TimeInterval) {
        animationTimerCancellable?.cancel()
        animationTimerCancellable = Just(())
            .delay(for: .seconds(duration), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.processEvent(.animationFinished)
            }
    }

    func cancelPendingAnimations() {
        animationTimerCancellable?.cancel()
        animationTimerCancellable = nil
    }
}
