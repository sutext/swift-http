//
//  HTTPClient.swift
//  HTTPDemo
//
//  Created by supertext on 2025/3/31.
//

import HTTP
import Foundation

let net = Client()
class Client:HTTPClient, HTTPDelegate,@unchecked Sendable{
    override init() {
        super.init()
        self.delegate = self
    }
    override var debug: Bool { true }
    override var headers: Headers{
        ["userid":"xxxxx"]
    }
    func client(_ client: HTTPClient, fillterRequest request: URLRequest) throws -> FilterResult {
        guard let str = request.url?.absoluteString else{
            throw HTTPError.invalidURL()
        }
        guard str.hasPrefix("http") else{
            throw HTTPError.invalidURL(str)
        }
        return .none
    }
}

protocol Model{
    init(_ data:Data)throws
}
struct ModelRequest<M:Model>:Request,ExpressibleByStringLiteral{
    var url: String{ path }
    var options: Options = .get()
    var httpParams: (any HTTPParams)?{ params }
    let path: String
    var params:JSONParams = [:]
    init(path: String) {
        self.path = path
    }
    func decode(_ data: Data) async throws -> M {
        try M(data)
    }
    init(stringLiteral value: StringLiteralType) {
        self.init(path: value)
    }
}
struct ConfigRequest:Request{
    var options: Options = .get()
    var url: String{ "https://accounts.google.com/.well-known/openid-configuration" }
    var params:JSONParams = [:]
    init() {
        params.username = "username"
        params.classmates = ["aa","bn","cc",true]
        params.isok = false
        params.age = 10
    }
    var httpParams: (any HTTPParams)?{ params }
    func decode(_ data: Data) async throws -> GoogleOidcConfig {
        try GoogleOidcConfig(data)
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
    init(_ data: Data) throws {
        let json = try JSON.parse(data)
        guard json != .null else{
            throw HTTPError.unexpectedResult
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
