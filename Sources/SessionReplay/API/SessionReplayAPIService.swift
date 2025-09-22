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

}
