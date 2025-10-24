import Foundation
import DataCompression

public final class GraphQLClient {
    public let endpoint: URL
    private let network: HttpServicing
    private let decoder: JSONDecoder
    private let defaultHeaders: [String: String]
    private let isCompressed: Bool = false
    
    public init(endpoint: URL,
                network: HttpServicing = HttpService(),
                decoder: JSONDecoder = JSONDecoder(),
                defaultHeaders: [String: String] = [
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                ]) {
        self.endpoint = endpoint
        self.network = network
        self.decoder = decoder
        self.defaultHeaders = defaultHeaders
    }

    /// Execute a GraphQL operation from stirng query
    /// - Parameters:
    ///   - query: Query in graphql format
    ///   - variables: Codable variables (optional)
    ///   - operationName: Operation name (optional)
    ///   - headers: Extra headers (merged over defaultHeaders)
    public func execute<Variables: Encodable, Output: Decodable>(
        query: String,
        variables: Variables? = nil,
        operationName: String? = nil,
        headers: [String: String] = [:]
    ) async throws -> Output {
        let gqlRequest = GraphQLRequest(query: query, variables: variables, operationName: operationName)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        
        let rawData = try gqlRequest.httpBody()
         
        if isCompressed, let compressedData = rawData.gzip() {
          request.httpBody = compressedData
          request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        } else {
          request.httpBody = rawData
        }
        
        let combinedHeaders = defaultHeaders.merging(headers) { _, new in new }
        combinedHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        do {
            let data = try await network.send(request)
            
            let envelope = try decoder.decode(GraphQLResponse<Output>.self, from: data)
            if let errors = envelope.errors, !errors.isEmpty {
                throw GraphQLClientError.graphQLErrors(errors)
            }
            guard let value = envelope.data else {
                throw GraphQLClientError.missingData
            }
            return value
        } catch let error as GraphQLClientError {
            throw error
        } catch let error as NetworkError {
            throw error
        } catch {
            throw GraphQLClientError.decoding(error)
        }
    }
    
    /// Execute a GraphQL operation where the query is loaded from a .graphql file in a bundle.
    /// - Parameters:
    ///   - resource: Filename without extension (e.g., "GetUser")
    ///   - ext: File extension (defaults to "graphql")
    ///   - bundle: Bundle to search (defaults to .main)
    ///   - variables: Codable variables (optional)
    ///   - operationName: Operation name (optional)
    ///   - headers: Extra headers (merged over defaultHeaders)
    public func executeFromFile<Variables: Encodable, Output: Decodable>(
        resource: String,
        ext: String = "graphql",
        bundle: Bundle = Bundle.main,
        variables: Variables? = nil,
        operationName: String? = nil,
        headers: [String: String] = [:]
    ) async throws -> Output {
        guard let url = bundle.url(forResource: resource, withExtension: ext) else {
            throw GraphQLClientError.queryFileNotFound("\(resource).\(ext)")
        }

        let query: String
        do {
            query = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw GraphQLClientError.unreadableQueryFile(url, error)
        }

        return try await execute(
            query: query,
            variables: variables,
            operationName: operationName,
            headers: headers
        )
    }
}

/// Standard GraphQL envelope: { data, errors }
private struct GraphQLResponse<DataType: Decodable>: Decodable {
    let data: DataType?
    let errors: [GraphQLError]?
}

public enum GraphQLClientError: Error, CustomStringConvertible {
    case graphQLErrors([GraphQLError])
    case missingData
    case decoding(Error)
    case queryFileNotFound(String)
    case unreadableQueryFile(URL, Error?)

    public var description: String {
        switch self {
        case .graphQLErrors(let errors):
            return "GraphQL errors: \(errors.map(\.message).joined(separator: " | "))"
        case .missingData:
            return "Missing `data` in GraphQL response"
        case .decoding(let error):
            return "Decoding error: \(error)"
        case .queryFileNotFound(let name):
            return "GraphQL file '\(name)' not found in bundle"
        case .unreadableQueryFile(let url, let err):
            return "Could not read GraphQL file at \(url). \(err?.localizedDescription ?? "")"
        }
    }
}

public struct GraphQLError: Decodable {
    public let message: String
}

public struct GraphQLEmptyData: Decodable {}

extension GraphQLClient {
    public func executeIgnoringData<Variables: Encodable>(
        query: String,
        variables: Variables? = nil,
        operationName: String? = nil,
        headers: [String: String] = [:]
    ) async throws {
        // Reuse EmptyData so decoding still works with `{ "data": null }` or `{ "data": {} }`
        _ = try await execute(
            query: query,
            variables: variables,
            operationName: operationName,
            headers: headers
        ) as GraphQLEmptyData
    }

    public func executeFromFileIgnoringData<Variables: Encodable>(
        resource: String,
        ext: String = "graphql",
        bundle: Bundle = .main,
        variables: Variables? = nil,
        operationName: String? = nil,
        headers: [String: String] = [:]
    ) async throws {
        _ = try await executeFromFile(
            resource: resource,
            ext: ext,
            bundle: bundle,
            variables: variables,
            operationName: operationName,
            headers: headers
        ) as GraphQLEmptyData
    }
}
