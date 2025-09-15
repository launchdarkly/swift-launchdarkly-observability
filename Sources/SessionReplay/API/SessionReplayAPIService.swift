import Foundation
import Common


public final class SessionReplayAPIService {
    let gqlClient: GraphQLClient
    
    init(gqlClient: GraphQLClient) {
        self.gqlClient = gqlClient
    }
    
    public convenience init() {
        let networkClient = URLSessionNetworkClient()
        let headers = ["accept-encoding": "gzip, deflate, br, zstd",
                       "Content-Type": "application/json"]
        
        self.init(gqlClient: GraphQLClient(endpoint: URL(string: "https://pub.observability.ld-stg.launchdarkly.com/")!,
                                           network: networkClient,
                                           defaultHeaders: headers))
    }
    
    public func initializeSession(session: ReplaySession) async throws {
        throw GraphQLClientError.missingData
        
        //        guard let jsonDict = Bundle.main.loadJSONDictionary(from: "initializeSession.json") else {
//            throw ScreenshotServiceError.loadingJSONFailed
//        }
//
//        // Generate a new session secure ID
//        let sessionSecureId = generateSecureID() //"m4uE9fMRuk6w4wHP5CE5Qy39lYhZ"
//        
//        // Update the variables in the JSON dictionary with the new session secure ID
//        guard var variables = jsonDict["variables"] as? [String: Any] else {
//            throw ScreenshotServiceError.loadingJSONFailed
//        }
//        
//        variables["session_secure_id"] = sessionSecureId
//        
//        // Update the clientConfig to replace the placeholder with the actual session secure ID
//        if let clientConfig = variables["clientConfig"] as? String {
//            let updatedClientConfig = clientConfig.replacingOccurrences(of: "{session_secure_id}", with: sessionSecureId)
//            variables["clientConfig"] = updatedClientConfig
//        }
//        
//        // Update the jsonDict with the modified variables
//        var updatedJsonDict = jsonDict
//        updatedJsonDict["variables"] = variables
//        
//        let requestBodyData = try! JSONSerialization.data(withJSONObject: updatedJsonDict, options: [])
//        print("Sending initializeSession:")
//        print(String(data: requestBodyData, encoding: .utf8) ?? "Bad JSON")
//
//
//        var request = URLRequest(url: URL(string: "https://pub.observability.ld-stg.launchdarkly.com/")!)
//        request.httpBody = requestBodyData
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.addValue("pub.observability.ld-stg.launchdarkly.com", forHTTPHeaderField: "authority")
//        request.addValue("*/*", forHTTPHeaderField: "accept")
//        request.addValue("gzip, deflate, br, zstd", forHTTPHeaderField: "accept-encoding")
//        request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "accept-language")
//        request.addValue("http://localhost:5173", forHTTPHeaderField: "origin")
//        request.addValue("u=1, i", forHTTPHeaderField: "priority")
//        request.addValue("http://localhost:5173/", forHTTPHeaderField: "referer")
//        request.addValue("`Not;A=Brand`", forHTTPHeaderField: "sec-ch-ua")
//        request.addValue("`99`", forHTTPHeaderField: "sec-ch-ua-mobile")
//        request.addValue("`macOS`", forHTTPHeaderField: "sec-ch-ua-platform")
//        request.addValue("empty", forHTTPHeaderField: "sec-fetch-dest")
//        request.addValue("cors", forHTTPHeaderField: "sec-fetch-mode")
//        request.addValue("cross-site", forHTTPHeaderField: "sec-fetch-site")
//        do {
//            let (data, reponse) = try await URLSession.shared.data(for: request)
//            print(String(data: data, encoding: .utf8) ?? "No data, response: \(reponse)")
//            
//            guard let sessionData = try? JSONDecoder().decode(InitializeSessionResponseWrapper.self, from: data) else {
//                throw ScreenshotServiceError.decodingError(nil)
//            }
//            let session = sessionData.data.initializeSession
//            print("Secure ID: \(session.secureId)")
//            print("Project ID: \(session.projectId)")
//            
//            print("Session initialized - Secure ID: \(session.secureId), Project ID: \(session.projectId)")
//            return session
//        } catch let error as DecodingError {
//            throw ScreenshotServiceError.decodingError(error)
//        } catch let error {
//            throw ScreenshotServiceError.networkError(error)
//        }
    }

    public func pushPayload(_ pushPayloadInput: PushPayloadInput) async throws {
        let bundle = Bundle(for: SessionReplayAPIService.self)
        let _: GraphQLEmptyData = try await gqlClient.executeFromFile(
            resource: "PushPayload",
            bundle: bundle,
            variables: pushPayloadInput,
            operationName: "PushPayload")
    }
}
