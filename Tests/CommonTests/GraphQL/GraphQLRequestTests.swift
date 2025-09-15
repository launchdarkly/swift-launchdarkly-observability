import Foundation
import Testing
@testable import Common

@Suite("GraphQLRequest")
struct GraphQLRequestTests {
    private struct Vars: Encodable {
        let id: String;
        let limit: Int
    }
    
    @Test("Encodes query + variables + operationName")
    func encodesQueryVariablesAndOperationName() throws {
        
        let req = GraphQLRequest(
            query: "query Q($id: ID!, $limit: Int!) { user(id: $id) { id } }",
            variables: Vars(id: "123", limit: 10),
            operationName: "Q"
        )
        
        let data = try req.httpBody()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json?["query"] as? String == "query Q($id: ID!, $limit: Int!) { user(id: $id) { id } }")
        #expect(json?["operationName"] as? String == "Q")
        
        let vars = json?["variables"] as? [String: Any]
        #expect(vars?["id"] as? String == "123")
        #expect(vars?["limit"] as? Int == 10)
    }
    
    @Test("Encodes [String: AnyEncodable] variables")
    func encodesAnyEncodableDictionaryVariables() throws {
        let variables: [String: String] = [
            "id": "abc",
            "count": "5",
            "flags": "a",
            "meta": "k"
        ]
        
        let req = GraphQLRequest(query: "query Q { _ }", variables: variables)
        let data = try req.httpBody()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let vars = json?["variables"] as? [String: Any]
        
        #expect(vars?["id"] as? String == "abc")
        #expect(vars?["count"] as? String == "5")
    }
}
