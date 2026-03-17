import Foundation

public enum NetworkError: Error, CustomStringConvertible {
    case invalidRequest(cause: Error)
    case invalidResponse
    case httpStatus(Int, data: Data?)
    case transport(Error)

    public var description: String {
        switch self {
        case .invalidResponse: return "Invalid response type"
        case .httpStatus(let code, let data):
            let dataString = data.map { String(data: $0, encoding: .utf8) } ?? "None"
            return "HTTP status \(code), data \(dataString)"
        case .transport(let error): return "Transport error: \(error)"
        case .invalidRequest(let cause): return "Invalid request: \(cause)"
        }
    }
}

public protocol HttpServicing {
    @discardableResult
    func send(_ request: URLRequest) async throws -> Data
}

public final class HttpService: HttpServicing {
//    func buildUserAgent(sdkVersion: String) -> String {
//        let device = UIDevice.current
//        let osVersion = device.systemVersion.replacingOccurrences(of: ".", with: "_")
//        let model = device.model // "iPhone" or "iPad"
//        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
//        
//        if model == "iPad" {
//            return "Mozilla/5.0 (\(model); CPU OS \(osVersion) like Mac OS X) Mobile/\(buildNumber) YourSDK/\(sdkVersion)"
//        } else {
//            return "Mozilla/5.0 (\(model); CPU \(model) OS \(osVersion) like Mac OS X) Mobile/\(buildNumber) YourSDK/\(sdkVersion)"
//        }
//    }

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
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(error)
        }
    }
}
