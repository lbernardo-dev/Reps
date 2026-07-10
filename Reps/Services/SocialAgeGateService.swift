import Foundation
import UIKit
import DeclaredAgeRange

@MainActor
enum SocialAgeGateService {
    enum Result: Equatable {
        case allowed13Plus
        case blockedUnder13
        case sharingDeclined
        case unavailable
    }

    static func requestSocialMediaEligibility() async -> Result {
        guard let viewController = UIApplication.shared.repsTopViewController else {
            return .unavailable
        }

        do {
            let response = try await AgeRangeService.shared.requestAgeRange(
                ageGates: 13,
                in: viewController
            )
            switch response {
            case .declinedSharing:
                return .sharingDeclined
            case .sharing(let range):
                if let lowerBound = range.lowerBound, lowerBound >= 13 {
                    return .allowed13Plus
                }
                return .blockedUnder13
            @unknown default:
                return .unavailable
            }
        } catch {
            return .unavailable
        }
    }
}

private extension UIApplication {
    var repsTopViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .repsTopPresentedViewController
    }
}

private extension UIViewController {
    var repsTopPresentedViewController: UIViewController {
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.repsTopPresentedViewController ?? navigation
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.repsTopPresentedViewController ?? tab
        }
        if let presentedViewController {
            return presentedViewController.repsTopPresentedViewController
        }
        return self
    }
}
