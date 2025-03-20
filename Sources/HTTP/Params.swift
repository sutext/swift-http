//
//  Params.swift
//  HTTP
//
//  Created by supertext on 2025/3/19.
//

import Foundation

public protocol HTTPParams{
    /// http body data only exist in `post` `put` and so on
    /// Only one of the `query` and `body` will be encode into the request
    var body:Data?{ get }
    /// http query string only exist in `get` `delete` `head` `conect`.
    /// Only one of the `query` and `body` will be encode into the request
    var query:URLQuery? { get }
    /// http query string  exist in `post` `put` and so on.
    var bodyQuery:URLQuery? { get }
    /// http content type only exist in `post` `put` and so on
    var contentType:String { get }
}
extension HTTPParams{
    /// most time bodyQuery is nil
    public var bodyQuery:URLQuery? { nil }
}
public struct URLParams:HTTPParams,ExpressibleByDictionaryLiteral,Sendable{
    private var values:[String: any JSONValue]
    public init(values:[String: any JSONValue] = [:]) {
        self.values = values
    }
    public init(dictionaryLiteral elements: (String,any JSONValue)...) {
        self.values = elements.reduce(into: [:], { $0[$1.0] = $1.1 })
    }
    public var contentType: String { "application/x-www-form-urlencoded; charset=utf-8" }
    public var body: Data? { query?.value?.data(using: .utf8)  }
    public var query: URLQuery? { URLQuery(values) }
    public subscript(key:String)->(any JSONValue)?{
        get { values[key] }
        set { values[key] = newValue}
    }
}

public struct JSONParams:HTTPParams,ExpressibleByDictionaryLiteral,Sendable{
    private var values:[String: any JSONValue]
    public init(values:[String: any JSONValue] = [:]) {
        self.values = values
    }
    public init(dictionaryLiteral elements: (String,any JSONValue)...) {
        self.values = elements.reduce(into: [:], { $0[$1.0] = $1.1 })
    }
    public var contentType: String { "application/json" }
    public var body: Data? { try? JSONSerialization.data(withJSONObject: self)  }
    public var query: URLQuery? { URLQuery(values) }
    public subscript(key:String)->(any JSONValue)?{
        get { values[key] }
        set { values[key] = newValue}
    }
}

public struct PlistParams:HTTPParams,ExpressibleByDictionaryLiteral,Sendable{
    private var values:[String: any JSONValue]
    public init(values:[String: any JSONValue] = [:]) {
        self.values = values
    }
    public init(dictionaryLiteral elements: (String,any JSONValue)...) {
        self.values = elements.reduce(into: [:], { $0[$1.0] = $1.1 })
    }
    public var contentType: String { "application/plist" }
    public var body: Data? { try? PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: .zero)  }
    public var query: URLQuery? { URLQuery(values) }
    public subscript(key:String)->(any JSONValue)?{
        get { values[key] }
        set { values[key] = newValue}
    }
}

/// Creates a url-encoded query string to be set as or appended to any existing URL query string or set as the HTTP
/// body of the URL request. Whether the query string is set or appended to any existing URL query string or set as
/// the HTTP body depends on the destination of the encoding.
///
/// The `Content-Type` HTTP header field of an encoded request with HTTP body is set to
/// `application/x-www-form-urlencoded; charset=utf-8`.
///
/// There is no published specification for how to encode collection types. By default the convention of appending
/// `[]` to the key for array values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for
/// nested dictionary values (`foo[bar]=baz`) is used. Optionally, `arrayBracket` can be used to omit the
/// square brackets appended to array keys.
///
/// `boolNumeric` can be used to configure how boolean values are encoded. The default behavior is to encode
/// `true` as 1 and `false` as 0.
///
public struct URLQuery:Sendable{
    private let values:[String:Sendable&Codable]
    private let boolNumeric:Bool
    private let arrayBrackets:Bool
    /// Creates an instance using the specified parameters.
    ///
    /// - Parameters:
    ///   - arrayBracket: if `true` an empty set of square brackets is appended to the key for every value
    ///   - boolNumeric:  if `true` encode `true` as `1` and `false` as `0` otherwise encode `true` and `false` as string literals.
    public init(_ values:[String:Sendable&Codable],arrayBrackets: Bool = true, boolNumeric: Bool = true) {
        self.values = values
        self.arrayBrackets = arrayBrackets
        self.boolNumeric = boolNumeric
    }
    /// Get the percent-escaped, URL encoded query string from the given key-value paiirs.
    public var value:String?{
        if values.isEmpty{ return nil }
        var components: [(String, String)] = []
        for key in values.keys.sorted(by: <) {
            let value = values[key]!
            components += encode(key, value: value)
        }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    /// Creates a percent-escaped, URL encoded query string components from the given key-value pair recursively.
    ///
    /// - Parameters:
    ///   - key:   Key of the query component.
    ///   - value: Value of the query component.
    ///
    /// - Returns: The percent-escaped, URL encoded query string components.
    private func encode(_ key:String ,value:Any) -> [(String, String)] {
        var components: [(String, String)] = []
        switch value {
        case let bool as Bool:
            components.append((escape(key), escape(encode(bool: bool))))
        case let string as String:
            components.append((escape(key), escape("\(string)")))
        case let number as NSNumber:
            components.append((escape(key), escape("\(number)")))
        case let object as [String:Any] :
            for (nestedKey, value) in object {
                components += encode("\(key)[\(nestedKey)]", value: value)
            }
        case let array as [Any]:
            for value in array {
                components += encode(encode(array: key), value: value)
            }
        default:
            break
        }
        return components
    }
    private func encode(array key:String)->String{
        if arrayBrackets{
            return "\(key)[]"
        }
        return key
    }
    private func encode(bool value:Bool)->String{
        if boolNumeric{
            return value ? "1" : "0"
        }
        return value ? "true" : "false"
    }
    /// Creates a percent-escaped string following RFC 3986 for a query string key or value.
    ///
    /// - Parameter string: `String` to be percent-escaped.
    ///
    /// - Returns:          The percent-escaped `String`.
    private func escape(_ string: String) -> String {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        let set = CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
        return string.addingPercentEncoding(withAllowedCharacters: set) ?? string
    }
}
extension URLRequest{
    mutating func addQuery(_ query:URLQuery){
        guard let url,let query = query.value else{ return }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        if query.isEmpty { return }
        if let percentEncodedQuery = components.percentEncodedQuery{
            components.percentEncodedQuery = percentEncodedQuery + "&" + query
        }else{
            components.percentEncodedQuery = query
        }
        if let url = components.url{
            self.url = url
        }
    }
    static func create(_ url:URL,method:HTTP.Method,params:HTTPParams?,headers:HTTP.Headers?,timeout:TimeInterval?)->URLRequest{
        var req = URLRequest(url:url , cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout ?? 0)
        if let headers{
            req.allHTTPHeaderFields = headers.values
        }
        req.httpMethod = method.rawValue
        guard let params else{ return req  }
        switch method {
        case .get,.head,.delete,.connect:
            if let query = params.query{
                req.addQuery(query)
            }
        default:
            if let query = params.bodyQuery{
                req.addQuery(query)
            }
            if let body = params.body{
                req.setHeader(params.contentType, for: .contentType)
                req.httpBody = body
            }
        }
        return req
    }
    static func query(_ url:URL,method:HTTP.Method,params:HTTPParams?,headers:HTTP.Headers?,timeout:TimeInterval?)->URLRequest{
        var req = URLRequest(url:url , cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout ?? 0)
        if let headers{
            req.allHTTPHeaderFields = headers.values
        }
        req.httpMethod = method.rawValue
        if let query = params?.query{
            req.addQuery(query)
        }
        return req
    }
}
