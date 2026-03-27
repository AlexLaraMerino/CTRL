import SwiftUI
import UIKit

final class OrientationController {
    static let shared = OrientationController()

    private init() {}

    var currentMask: UIInterfaceOrientationMask = .landscape

    func set(mask: UIInterfaceOrientationMask, preferred orientation: UIInterfaceOrientation) {
        currentMask = mask
        _ = orientation

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
