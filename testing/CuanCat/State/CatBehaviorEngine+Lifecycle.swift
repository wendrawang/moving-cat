import Foundation
import UIKit

// MARK: - Lifecycle (Day Change Observer & Cleanup)
//
// Dipisah ke file sendiri agar CatBehaviorEngine.swift tetap ringkas.
// observeDayChange dipanggil sekali dari init; cleanup dari hide() + deinit.

extension CatBehaviorEngine {

    func observeDayChange() {
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.processEvent(.dayChanged)
        }
    }

    func cleanup() {
        CatAudioManager.shared.stopAll()
        walkTimerCancellable?.cancel()
        idleTimerCancellable?.cancel()
        loadingTimerCancellable?.cancel()
        animationTimerCancellable?.cancel()
        afkTimerCancellable?.cancel()
        stageLabelTimerCancellable?.cancel()

        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
