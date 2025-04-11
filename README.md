# swift-http
![Platform](https://img.shields.io/badge/platforms-iOS%2013.0%20%7C%20macOS%2010.15%20%7C%20tvOS%2013.0%20%7C%20watchOS%206.0-F28D00.svg)
- An http client wrapper by URLSession. Just like [Alamofire](https://github.com/Alamofire/Alamofire) and [Moya](https://github.com/Moya/Moya)
- Unlike them `swift-http` is designed to be simple and lightweight in an easily extensible style
- Unlike them `swift-http` use a new pattern of asynchronous programming. Just look at `Javascript` `Promise` for design ideas

## Requirements

- iOS 13.0+ | macOS 10.15+ | tvOS 13.0+ | watchOS 6.0+
- Xcode 8

## Integration

#### Swift Package Manager

You can use [The Swift Package Manager](https://swift.org/package-manager) to install `swift-promise` by adding the proper description to your `Package.swift` file:

```swift
// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "YOUR_PROJECT_NAME",
    dependencies: [
        .package(url: "https://github.com/sutext/swift-http.git", from: "1.0.0"),
    ]
)
```

### Usage

```swift
let net = Client()
class Client:HTTPClient, HTTPDelegate,@unchecked Sendable{
    override init() {
        super.init()
        self.debug = true
        self.delegate = self
    }
    func client(_ client: HTTPClient, fillterRequest request: URLRequest) throws -> FilterResult {
        guard let str = request.url?.absoluteString else{
            throw HTTPError.invalidURL(url: "")
        }
        guard str.hasPrefix("http") else{
            throw HTTPError.invalidURL(url: str)
        }
        return .none
//        var result = JSON([:])
//        result.code = "ok"
//        result.message = "test directly return"
//        return .response(.success(result.rawData!))
    }
}


struct JSONRequest:Request,ExpressibleByStringLiteral{
    var url: String{ path }
    var options: Options? = .init()
    var parameters:HTTPParams?{ params }
    
    let path: String
    var params:JSON = [:]
    init(path: String) {
        self.path = path
    }
    func decode(_ data: Data) async throws -> JSON {
        try JSON.parse(data)
    }
    init(stringLiteral value: StringLiteralType) {
        self.init(path: value)
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
struct ConfigRequest:Request{
    var options: Options?{ .get() }
    var parameters: (any HTTPParams)? { nil }
    var url: String{ "https://accounts.google.com/.well-known/openid-configuration" }
    func decode(_ data: Data) async throws -> GoogleOidcConfig {
        try GoogleOidcConfig(JSON.parse(data))
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

let config = try await net.request(ConfigRequest()).wait()
print(config)

```
