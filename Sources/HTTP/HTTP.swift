//
//  HTTP.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation
@_exported import JSON
@_exported import Promise

///HTTP  Errors
@frozen public enum HTTPError:Swift.Error{
    case invalidURL(String? = nil) // invalid url when encode URLRequest
    case invalidStatus(code:Int,debug:String? = nil) // invalid http status in response
    case invalidResponse(URLResponse? = nil) // invalid resoponse
    case unexpectedResult // unexpected data when decode response to `Request.Result`
    case downloadFileNotFound // can not found the download file
}
///HTTP request methods
@frozen public enum Method:String,Sendable{
    case get = "GET"
    case put = "PUT"
    case head = "HEAD"
    case post = "POST"
    case trace = "TRACE"
    case patch = "PATCH"
    case delete = "DELETE"
    case connect = "CONNECT"
    case options = "OPTIONS"
}

///HTTP Headers
@frozen public struct Headers :Sendable{
    public enum Field:String {
        case accept             = "Accept"
        case acceptCharset      = "Accept-Charset"
        case acceptLanguage     = "Accept-Language"
        case acceptEncoding     = "Accept-Encoding"
        case authorization      = "Authorization"
        case contentType        = "Content-Type"
        case contentDisposition = "Content-Disposition"
        case userAgent          = "User-Agent"
    }
    public private(set) var values: [String:String]
    public init(_ values:[String:String]? = nil) {
        self.values = values ?? [:]
    }
    /// Append sigle header value for field
    public mutating func append(_ value:String,field:String){
        self.values[field] = value
    }
    /// Append sigle header value for field
    public mutating func append(_ value:String,field:Field){
        self.values[field.rawValue] = value
    }
    /// Append other headers
    public mutating func append(_ other:[String:String]){
        for item in other {
            self.values[item.key] = item.value
        }
    }
    /// Append other headers
    public mutating func append(_ other:[Field:String]){
        for item in other {
            self.values[item.key.rawValue] = item.value
        }
    }
    /// Append other headers
    public mutating func append(_ other:Headers){
        for item in other.values {
            self.values[item.key] = item.value
        }
    }
    /// Append Basic Authorization header
    public mutating func authorization(basic username:String,password:String){
        let credential = Data("\(username):\(password)".utf8).base64EncodedString()
        self[.authorization] = "Basic \(credential)"
    }
    /// Append  Bearer Authorization header
    public mutating func authorization(bearer token:String){
        self[.authorization] = "Bearer \(token)"
    }
    /// String subscript access
    ///
    ///     options.headers["your-custom-header"] = "custom value"
    ///     options.headers["your-custom-header"] = nil // remove some field
    ///
    public subscript(_ name: String) -> String? {
        get { values[name] }
        set { values[name] = newValue }
    }
    /// Field subscript access
    ///
    ///     options.headers[.contentType] = "application/json"
    ///     options.headers[.contentType] = nil // remove contentType
    ///
    public subscript(_ field: Field) -> String? {
        get { values[field.rawValue] }
        set { values[field.rawValue] = newValue }
    }
    /// default headers that will be add to `config.httpAdditionalHeaders`
    public static let `default`:Headers = [
        Field.userAgent.rawValue:defaultUserAgent,
        Field.acceptEncoding.rawValue:defaultAcceptEncoding
    ]
    /// See the [Accept-Encoding HTTP header documentation](https://tools.ietf.org/html/rfc7230#section-4.2.3) .
    public static let defaultAcceptEncoding: String = {
        let encodings: [String]
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            encodings = ["br", "gzip", "deflate"]
        } else {
            encodings = ["gzip", "deflate"]
        }
        return encodings.qualityEncoded()
    }()

    /// See the [Accept-Language HTTP header documentation](https://tools.ietf.org/html/rfc7231#section-5.3.5).
    public static let defaultAcceptLanguage: String = {
        Locale.preferredLanguages.prefix(6).qualityEncoded()
    }()
    /// See the [User-Agent header documentation](https://tools.ietf.org/html/rfc7231#section-5.5.3).
    ///
    /// Example: `Example/1.0 (com.example.app; build:1; iOS 13.0.0) SwiftHTTP/1.0.0`
    public static let defaultUserAgent: String = {
        let info = Bundle.main.infoDictionary
        let executable = (info?[kCFBundleExecutableKey as String] as? String) ??
            (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
            "Unknown"
        let bundle = info?[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info?[kCFBundleVersionKey as String] as? String ?? "Unknown"
        let osName = getOsName()
        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            return "\(osName) \(versionString)"
        }()
        return  "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) SwiftHTTP/1.5.2"
    }()
    private static func getOsName()->String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "Darwin"
        #endif
    }
}
extension Headers:ExpressibleByDictionaryLiteral{
    public init(dictionaryLiteral elements: (String, String)...) {
        self.values = elements.reduce(into: [:]){$0[$1.0]=$1.1}
    }
}
extension RandomAccessCollection where Element == String {
    fileprivate func qualityEncoded() -> String {
        enumerated().map { index, encoding in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(encoding);q=\(quality)"
        }.joined(separator: ", ")
    }
}
@frozen public struct Options:Sendable{
    ///the request method
    public var method:Method
    ///overwrite the global baseURL
    public var baseURL:String?
    /// merge into global headers
    public var headers:Headers
    /// overwrite global timeout settings
    public var timeout:TimeInterval?
    /// overwrite the global retrier settings
    public var retrier:Retrier?
    public init(_ method:Method,baseURL:String?=nil,headers:Headers=[:],timeout:TimeInterval?=nil,retrier:Retrier?=nil){
        self.method = method
        self.baseURL = baseURL
        self.retrier = retrier
        self.headers = headers
        self.timeout = timeout
    }
    
    public static func get(base:String? = nil,headers:Headers=[:],timeout:TimeInterval? = nil,retrier:Retrier?=nil)->Options{
        .init(.get,baseURL: base,headers: headers,timeout: timeout,retrier: retrier)
    }
    public static func put(base:String? = nil,headers:Headers=[:],timeout:TimeInterval? = nil,retrier:Retrier?=nil)->Options{
        .init(.put,baseURL: base,headers: headers,timeout: timeout,retrier: retrier)
    }
    public static func post(base:String? = nil,headers:Headers=[:],timeout:TimeInterval? = nil,retrier:Retrier?=nil)->Options{
        .init(.post,baseURL: base,headers: headers,timeout: timeout,retrier: retrier)
    }
    public static func delete(base:String? = nil,headers:Headers=[:],timeout:TimeInterval? = nil,retrier:Retrier?=nil)->Options{
        .init(.delete,baseURL: base,headers: headers,timeout: timeout,retrier: retrier)
    }
}
