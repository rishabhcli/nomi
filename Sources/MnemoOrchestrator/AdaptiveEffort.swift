import Foundation

/// Chooses reasoning effort dynamically (intelligence #6): spend more on hard
/// or poorly-covered questions, stay cheap on trivial ones.
public enum AdaptiveEffort {
    public static func select(_ policy: EffortPolicy, intent: Intent,
                              coverageWeak: Bool, decomposed: Bool) -> String {
        // Hard signals → high effort.
        if intent == .multihop || coverageWeak || decomposed { return policy.multihop }
        return policy.forIntent(intent)
    }
}
