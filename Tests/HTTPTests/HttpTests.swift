import XCTest
@testable import HTTP

class Client:HTTPClient,@unchecked Sendable{
    override init() {
        super.init()
        self.debug = true
        self.delegate = self
    }
}
extension Client:HTTPDelegate{
    func client(_ client: HTTPClient, shouldUpdate config: URLSessionConfiguration) {
        
    }
    func client(_ client: HTTPClient, task: URLSessionTask, didReceive challenge: Challenge) -> ChallengeResult {
        .useDefault
    }
}
protocol Model{
    init(_ json:JSON)throws
}
struct ModelRequest<M:Model>:Request,ExpressibleByStringLiteral{
    var url: String{ path }
    var options: Options? = .init()
    var parameters:HTTPParams?{ params }
    
    let path: String
    var params:JSON = [:]
    init(path: String) {
        self.path = path
    }
    func decode(_ data: Data) async throws -> M {
        try M(JSON.parse(data))
    }
    init(stringLiteral value: StringLiteralType) {
        self.init(path: value)
    }
}
struct GoogleOidcConfig:Model{
    var issuer:String?
    var jwks_uri:String?
    var token_endpoint:String?
    var userinfo_endpoint:String?
    var revocation_endpoint:String?
    var authorization_endpoint:String?
    var device_authorization_endpoint:String?
    var scopes_supported:[String]
    var claims_supported:[String]
    var subject_types_supported:[String]
    var response_types_supported:[String]
    var grant_types_supported:[String]
    var code_challenge_methods_supported:[String]
    var token_endpoint_auth_methods_supported:[String]
    var id_token_signing_alg_values_supported:[String]
    init(_ json: JSON) throws {
        guard json != .null else{
            throw HTTPError.invalidResponseData
        }
        issuer = json.issuer.string
        jwks_uri = json.jwks_uri.string
        token_endpoint = json.token_endpoint.string
        userinfo_endpoint = json.userinfo_endpoint.string
        revocation_endpoint = json.revocation_endpoint.string
        authorization_endpoint = json.authorization_endpoint.string
        device_authorization_endpoint = json.device_authorization_endpoint.string
        scopes_supported = json.scopes_supported.compactMap{ $1.string }
        claims_supported = json.claims_supported.compactMap{ $1.string }
        subject_types_supported = json.subject_types_supported.compactMap{ $1.string }
        grant_types_supported = json.grant_types_supported.compactMap{ $1.string }
        response_types_supported = json.response_types_supported.compactMap { $1.string }
        code_challenge_methods_supported = json.code_challenge_methods_supported.compactMap{ $1.string }
        token_endpoint_auth_methods_supported = json.token_endpoint_auth_methods_supported.compactMap{ $1.string }
        id_token_signing_alg_values_supported = json.id_token_signing_alg_values_supported.compactMap{ $1.string }
    }
}
final class HttpTests: XCTestCase {
    let client = Client()
    func testGet() async throws {
        var req:ModelRequest<GoogleOidcConfig> = "https://accounts.google.com/.well-known/openid-configuration"
        req.params.username = "hello"
        req.params.password = "xxxxx"
        req.options?.method = .get
        let config = try await client.request(req).wait()
        XCTAssertNotNil(config.issuer)
    }
    func testGet1() async throws {
        let url = "https://accounts.google.com/.well-known/openid-configuration"
        let data = try await client.request(url,options: .get()).wait()
        let json = try JSON.parse(data)
        let config = try GoogleOidcConfig(json)
        XCTAssertNotNil(config.issuer)
    }
    func testGet2() async throws {
        let base = "https://accounts.google.com/"
        let data = try await client.request("/.well-known/openid-configuration",options: .get(base: base)).wait()
        let json = try JSON.parse(data)
        let config = try GoogleOidcConfig(json)
        XCTAssertNotNil(config.issuer)
    }
    func testGet3() async throws {
        var req:JSONRequest = "https://accounts.google.com/.well-known/openid-configuration"
        req.options = .get()
        let json = try await client.request(req).wait()
        let config = try GoogleOidcConfig(json)
        XCTAssertNotNil(config.issuer)
    }
}
