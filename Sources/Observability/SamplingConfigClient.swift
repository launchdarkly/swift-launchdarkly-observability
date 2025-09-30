import Common
import Sampling

protocol SamplingConfigClient {
    func getSamplingConfig(sdkKey: String) async throws -> SamplingConfig?
}

final class DefaultSamplingConfigClient: SamplingConfigClient {
    struct OrganizationVerboseIdVar: Encodable { let organization_verbose_id: String }
    private let client: GraphQLClient
    
    init(client: GraphQLClient) {
        self.client = client
    }
    
    func getSamplingConfig(sdkKey: String) async throws -> SamplingConfig? {
        let data: SamplingData = try await client.executeFromFile(
            resource: "GetSamplingConfigQuery",
            bundle: .module,
            variables: OrganizationVerboseIdVar(organization_verbose_id: sdkKey)
        )
        
        return data.sampling
    }
}
