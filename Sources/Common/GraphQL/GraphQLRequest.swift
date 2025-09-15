import Foundation

/// Encodes the GraphQL POST body: { query, variables, operationName }
public struct GraphQLRequest<Variables: Encodable>: Encodable {
    public let query: String
    public let variables: Variables?
    public let operationName: String?

    public init(query: String,
                variables: Variables? = nil,
                operationName: String? = nil) {
        self.query = query
        self.variables = variables
        self.operationName = operationName
    }

    /// Create the HTTP body data for this request.
    /// You can reuse this anywhere you need to build a GraphQL body.
    public func httpBody(encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        try encoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case query
        case variables
        case operationName
    }
}
