import Foundation

/// A small, deterministic, `Codable` random number generator (SplitMix64).
///
/// Determinism matters for Tumbler: the same seed always produces the same
/// shuffle, so a session can be persisted and resumed without holding a
/// decoded library in memory.
public struct SeededGenerator: RandomNumberGenerator, Codable, Equatable, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
