import Common
import Sampling

protocol SamplingConfigClient {
    func getSamplingConfig(mobileKey: String) async throws -> SamplingConfig?
}

final class DefaultSamplingConfigClient: SamplingConfigClient {
    struct OrganizationVerboseIdVar: Encodable { let organization_verbose_id: String }
    private let client: GraphQLClient
    
    init(client: GraphQLClient) {
        self.client = client
    }
    
    func getSamplingConfig(mobileKey: String) async throws -> SamplingConfig? {
        let data: SamplingData = try await client.executeFromFile(
            resource: "GetSamplingConfigQuery",
            bundle: .module,
            variables: OrganizationVerboseIdVar(organization_verbose_id: mobileKey)
        )
        
        return data.sampling
    }
}
