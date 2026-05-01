/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public enum CompressionType {
    case gzip
    case deflate
    case none
}

public struct OtlpConfiguration {
    public static let DefaultTimeoutInterval: TimeInterval = .init(10)

    public let headers: [(String, String)]?
    public let timeout: TimeInterval
    public let compression: CompressionType

    public init(timeout: TimeInterval = OtlpConfiguration.DefaultTimeoutInterval,
                compression: CompressionType = .gzip,
                headers: [(String, String)]? = nil) {
        self.headers = headers
        self.timeout = timeout
        self.compression = compression
    }
}
