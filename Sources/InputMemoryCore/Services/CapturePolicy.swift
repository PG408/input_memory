import Foundation

public enum CapturePolicy {
    public static func shouldSkipCandidate(
        appName: String,
        bundleID: String,
        role: String?,
        subrole: String?,
        value: String?
    ) -> Bool {
        if bundleID == "com.apple.loginwindow" || appName == "loginwindow" {
            return true
        }
        if subrole == "AXSecureTextField" {
            return true
        }
        if role == "AXTextField", subrole?.localizedCaseInsensitiveContains("secure") == true {
            return true
        }
        return false
    }
}
