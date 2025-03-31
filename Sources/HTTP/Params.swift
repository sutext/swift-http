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
    var body:HTTPBody?{ get }
    /// http query string only exist in `get` `delete` `head` `conect`.
    /// Only one of the `query` and `body` will be encode into the request
    var query:URLQuery? { get }
    /// http query string  exist in `post` `put` and so on.
    var bodyQuery:URLQuery? { get }
}
extension HTTPParams{
    /// most time bodyQuery is nil
    public var bodyQuery:URLQuery? { nil }
}

///`JSON` is also `JSONParams`
extension JSON:HTTPParams{
    public var body: HTTPBody?{
        guard let data = compactData else{
            return nil
        }
        return .json(data)
    }
    public var query: URLQuery?{
        guard let object else{
            return nil
        }
        return URLQuery(object)
    }
}

///Standardized Plist params encoding
///
public struct PlistParams:HTTPParams,ExpressibleByDictionaryLiteral,Sendable{
    private var values:AnyValue
    /// query params encoding
    public var query: URLQuery? { values.query }
    /// when application/plist
    public var body: HTTPBody? {
        guard let value = values.compactValue,
              let data = try? PropertyListSerialization.data(fromPropertyList: value, format: .xml, options:.zero) else{
            return nil
        }
        return .plist(data)
    }
    public init(_ value:AnyValue = [:]) {
        self.values = value
    }
    public init(dictionaryLiteral elements: (String,AnyValue)... ){
        self.values = .object(elements.reduce(into: [:], {
            $0[$1.0] = $1.1
        }))
    }
    public subscript(key:String)->AnyValue{
        get { values[key] }
        set { values[key] = AnyValue(newValue)}
    }
}
///Standardized URL encoding
public struct URLParams:HTTPParams,ExpressibleByDictionaryLiteral,Sendable{
    private var values:[String:AnyValue]
    /// query params encoding
    public var query: URLQuery? { URLQuery(values) }
    /// when application/x-www-form-urlencoded
    public var body: HTTPBody? {
        guard let data = query?.encode()?.data(using: .utf8) else{
            return nil
        }
        return .urlencoded(data)
    }
    public init(_ values:[String:Any]){
        self.values = AnyValue(values).objectValue
    }
    public init(_ values:[String:AnyValue] = [:]) {
        self.values = values
    }
    public init(dictionaryLiteral elements: (String,AnyValue)... ){
        self.values = elements.reduce(into: [:], {
            $0[$1.0] = $1.1
        })
    }
    public subscript(key:String)->AnyValue?{
        get { values[key] }
        set { values[key] = AnyValue(newValue)}
    }
}
public struct HTTPBody{
    public let data:Data
    public let contentType:String
    public static func xml(_ data:Data)->HTTPBody{
        .init(data: data, contentType: "application/xml")
    }
    public static func json(_ data:Data)->HTTPBody{
        .init(data: data, contentType: "application/json")
    }
    public static func plist(_ data:Data)->HTTPBody{
        .init(data: data, contentType: "application/plist")
    }
    public static func protobuf(_ data:Data)->HTTPBody{
        .init(data: data, contentType: "application/x-protobuf")
    }
    public static func urlencoded(_ data:Data)->HTTPBody{
        .init(data: data, contentType: "application/x-www-form-urlencoded; charset=utf-8")
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
    private let values:[String:AnyValue]
    private let boolNumeric:Bool
    private let arrayBrackets:Bool
    /// Creates an instance using the specified parameters.
    ///
    /// - Parameters:
    ///   - values: key-vallue dictionary
    ///   - arrayBracket: if `true` an empty set of square brackets is appended to the key for every value
    ///   - boolNumeric:  if `true` encode `true` as `1` and `false` as `0` otherwise encode `true` and `false` as string literals.
    public init(_ values:[String:AnyValue],arrayBrackets: Bool = true, boolNumeric: Bool = true) {
        self.values = values
        self.arrayBrackets = arrayBrackets
        self.boolNumeric = boolNumeric
    }
    public init(_ values:[String:Any],arrayBrackets: Bool = true, boolNumeric: Bool = true) {
        self.values = AnyValue(values).objectValue
        self.arrayBrackets = arrayBrackets
        self.boolNumeric = boolNumeric
    }
    /// Get the percent-escaped, URL encoded query string from the given key-value paiirs.
    public func encode()->String?{
        if values.isEmpty{ return nil }
        var components: [(String, String)] = []
        for key in values.keys.sorted(by: <) {
            let value = values[key]!
            components += encode(key, value: value)
        }
        if components.isEmpty { return nil }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    /// Creates a percent-escaped, URL encoded query string components from the given key-value pair recursively.
    ///
    /// - Parameters
    ///   - key:   Key of the query component.
    ///   - value: Value of the query component.
    ///
    /// - Returns: The percent-escaped, URL encoded query string components.
    private func encode(_ key:String ,value:AnyValue) -> [(String, String)] {
        var components: [(String, String)] = []
        switch value {
        case .bool(let bool):
            components.append((escape(key), escape(encode(bool: bool))))
        case .string(let string):
            components.append((escape(key), escape("\(string)")))
        case .number(let number):
            components.append((escape(key), escape("\(number)")))
        case .object(let object) :
            for (nestedKey, value) in object {
                if case .null = value{ continue }
                components += encode("\(key)[\(nestedKey)]", value: value)
            }
        case .array(let array):
            for value in array {
                if case .null = value{ continue }
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
        guard let url,let query = query.encode() else{ return }
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
                req.setHeader(body.contentType, for: .contentType)
                req.httpBody = body.data
            }
        }
        return req
    }
    static func query(_ url:URL,method:HTTP.Method,params:URLParams?,headers:HTTP.Headers?,timeout:TimeInterval?)->URLRequest{
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
