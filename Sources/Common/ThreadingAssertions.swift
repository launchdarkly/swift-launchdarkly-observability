import Foundation

// Threading assertion utilities for debugging builds.
#if DEBUG
@inline(__always)
public func debugAssertMainThread(file: StaticString = #file, line: UInt = #line) {
    precondition(Thread.isMainThread, "This must be called on the main thread", file: file, line: line)
}
#else
@inline(__always)
public func debugAssertMainThread(file: StaticString = #file, line: UInt = #line) {}
#endif
