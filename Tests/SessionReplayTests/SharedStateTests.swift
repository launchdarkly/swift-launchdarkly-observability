import Testing

/// Parent of the suites that set `LDReplay.shared` or `LDObserve.shared`, which would race if those suites ran in
/// parallel.
@Suite(.serialized)
struct SharedStateTests {}
