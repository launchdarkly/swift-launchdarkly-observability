import Foundation
import Testing
@testable import Common

// MARK: - Test helpers

private struct GetUserOut: Codable, Equatable {
    struct User: Codable, Equatable {
        let id: String
        let name: String
    }
    let user: User
}

private struct Vars: Encodable { let id: String }

private final class MockNetworkClient: NetworkClient {
    enum Mode {
        case succeed(Data),
             fail(Error)
    }
    var mode: Mode
    var lastRequest: URLRequest?
    
    init(mode: Mode) { self.mode = mode }
    
    func send(_ request: URLRequest) async throws -> Data {
        lastRequest = request
        switch mode {
        case .succeed(let data): return data
        case .fail(let error): throw error
        }
    }
}

private struct En: Encodable { let message: String }
private struct Env<T: Encodable>: Encodable { let data: T?; let errors: [En]? }

private func makeEnvelope<DataType: Encodable>(
    data: DataType?,
    errors: [String]? = nil
) throws -> Data {
    let env = Env(data: data, errors: errors?.map(En.init(message:)))
    return try JSONEncoder().encode(env)
}

@Suite("GraphQLClient")
struct GraphQLClientTests {
    
    @Test("Decodes success data and merges headers")
    func successDecodesData() async throws {
        // GIVEN
        let expected = GetUserOut(user: .init(id: "1", name: "Ada"))
        let payload = try makeEnvelope(data: expected)
        let mock = MockNetworkClient(mode: .succeed(payload))
        
        let client = GraphQLClient(
            endpoint: URL(string: "https://example.com/graphql")!,
            network: mock,
            decoder: JSONDecoder(),
            defaultHeaders: [
                "Authorization": "Bearer token",
                "Content-Type": "application/json", // default anyway
                "Accept": "application/json"
            ]
        )
        
        // WHEN
        let query = "query GetUser($id: ID!) { user(id: $id) { id name } }"
        let out: GetUserOut = try await client.execute(
            query: query,
            variables: Vars(id: "1"),
            operationName: "GetUser",
            headers: ["X-Trace-Id": "trace-1"]
        )
        
        // THEN
        #expect(out == expected)
        
        let req = try #require(mock.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(req.value(forHTTPHeaderField: "X-Trace-Id") == "trace-1")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(req.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(req.httpBody != nil)
    }
    
    @Test("Surfaces GraphQL errors")
    func graphQLErrorsAreSurfaced() async {
        let payload = try! makeEnvelope(data: Optional<GetUserOut>.none, errors: ["Oh no", "Bad var"])
        let mock = MockNetworkClient(mode: .succeed(payload))
        let client = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!, network: mock)
        
        await #expect(throws: GraphQLClientError.self) {
            let _: GetUserOut = try await client.execute(
                query: "query { _ }",
                variables: Vars(id: "x")
            )
        }
    }
    
    @Test("Throws on missing data (no errors)")
    func missingDataThrows() async {
        let payload = try! makeEnvelope(data: Optional<GetUserOut>.none, errors: nil)
        let mock = MockNetworkClient(mode: .succeed(payload))
        let client = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!, network: mock)
        
        await #expect(throws: GraphQLClientError.self) {
            let _: GetUserOut = try await client.execute(query: "query { _ }", variables: Vars(id: "x"))
        }
    }
    
    @Test("Throws on decoding error")
    func decodingErrorThrows() async {
        struct Wrong: Encodable { let wrong: String }
        let payload = try! makeEnvelope(data: Wrong(wrong: "nope"))
        let mock = MockNetworkClient(mode: .succeed(payload))
        let client = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!, network: mock)
        
        await #expect(throws: GraphQLClientError.self) {
            let _: GetUserOut = try await client.execute(query: "query { _ }", variables: Vars(id: "x"))
        }
    }
    
    @Test("Network errors propagate from NetworkClient")
    func networkErrorPropagates() async {
        let mock = MockNetworkClient(mode: .fail(NetworkError.httpStatus(401, data: Data("nope".utf8))))
        let client = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!, network: mock)
        
        await #expect(throws: NetworkError.self) {
            let _: GetUserOut = try await client.execute(query: "query { _ }", variables: Vars(id: "x"))
        }
    }
    
    @Test("Per-request headers override defaults")
    func perRequestHeadersOverrideDefaults() async throws {
        let expected = GetUserOut(user: .init(id: "1", name: "Ada"))
        let payload = try makeEnvelope(data: expected)
        let mock = MockNetworkClient(mode: .succeed(payload))
        let client = GraphQLClient(
            endpoint: URL(string: "https://example.com/graphql")!,
            network: mock,
            defaultHeaders: [
                "Authorization": "Bearer OLD",
                "Accept": "application/json"
            ]
        )
        
        let _: GraphQLEmptyData = try await client.execute(
            query: "query { _ }",
            variables: Vars(id: "1"),
            headers: ["Authorization": "Bearer NEW"]
        )
        
        let req = try #require(mock.lastRequest)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer NEW")
        #expect(req.value(forHTTPHeaderField: "Accept") == "application/json")
    }
    
    @Test("executeIgnoringData convenience")
    func executeIgnoringData() async throws {
        struct Trivial: Encodable {}
        let payload = try makeEnvelope(data: Trivial())
        let mock = MockNetworkClient(mode: .succeed(payload))
        let client = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!, network: mock)
        
        try await client.executeIgnoringData(
            query: "mutation { logout }",
            variables: ["reason": "user"]
        )
        
        #expect(mock.lastRequest?.httpBody != nil)
    }
    
    @Test("executeFromFile loads .graphql from bundle")
    func executeFromFileLoadsAndRuns() async throws {
        // Put GetUser.graphql in your TEST target resources:
        // 
        let expected = GetUserOut(user: .init(id: "42", name: "Linus"))
        let payload = try makeEnvelope(data: expected)
        let mock = MockNetworkClient(mode: .succeed(payload))
        let client = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!, network: mock)
        
        let out: GetUserOut = try await client.executeFromFile(
            resource: "getUser",
            bundle: Bundle.module,
            variables: Vars(id: "42"),
            operationName: "GetUser"
        )
        
        #expect(out == expected)
    }
    
    @Test("executeFromFile throws when file missing")
    func executeFromFileNotFoundThrows() async {
        let mock = MockNetworkClient(mode: .succeed(Data()))
        let client = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!, network: mock)
        let bundle = Bundle(for: DummyClass.self)

        await #expect(throws: GraphQLClientError.self) {
            let _: GetUserOut = try await client.executeFromFile(resource: "NoSuch",
                                                                 bundle: bundle,
                                                                 variables: Vars(id: "42"))
        }
    }
}

// Helper for non-SPM bundle lookup
private final class DummyClass {}
