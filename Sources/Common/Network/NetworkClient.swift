import Foundation

public enum NetworkError: Error, CustomStringConvertible {
    case invalidResponse
    case httpStatus(Int, data: Data?)
    case transport(Error)

    public var description: String {
        switch self {
        case .invalidResponse: return "Invalid response type"
        case .httpStatus(let code, _): return "HTTP status \(code)"
        case .transport(let error): return "Transport error: \(error)"
        }
    }
}

public protocol NetworkClient {
    func send(_ request: URLRequest) async throws -> Data
}

public final class URLSessionNetworkClient: NetworkClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            guard (200...299).contains(http.statusCode) else {
                throw NetworkError.httpStatus(http.statusCode, data: data)
            }
            return data
        } catch {
            throw NetworkError.transport(error)
        }
    }
}
