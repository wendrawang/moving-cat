//
//  testingApp.swift
//  testing
//
//  Created by Wen on 05/05/26.
//

import SwiftUI
import UIKit

// iOS 13 compatible entry point — UIApplicationDelegate + UIWindow.
// App protocol + WindowGroup membutuhkan iOS 14+.
@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Parse + build semua Lottie layer sebelum UI muncul.
        // show() akan menunggu ini selesai via DispatchGroup.
        CatOverlayManager.shared.prepare()

        let rootWindow = UIWindow(frame: UIScreen.main.bounds)
        rootWindow.rootViewController = UIHostingController(rootView: ContentView())
        rootWindow.makeKeyAndVisible()
        self.window = rootWindow
        return true
    }
}

struct FrameSizes {
    struct MainTabBar {
        static let height: CGFloat = 120
        static let paddingBottom: CGFloat = 0
    }
}

struct Spaces {
    static let extraSmall: CGFloat = 0
}
