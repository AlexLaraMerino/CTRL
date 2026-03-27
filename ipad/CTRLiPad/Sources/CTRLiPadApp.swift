import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationController.shared.currentMask
    }
}

@main
struct CTRLiPadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DailyBoardStore()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(store)
        }
    }
}
