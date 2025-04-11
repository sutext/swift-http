//
//  Params.swift
//  HTTP
//
//  Created by supertext on 2025/3/19.
//

import Foundation

public protocol HTTPParams{
    /// http body data. Only exist in `post` `put` and so on
    /// Only one of the `query` and `body` will be encode into the request
    var body:HTTPBody?{ get }
    /// http query string .Only exist in `get` `delete` `head` `conect`.
    /// Only one of the `query` and `body` will be encode into the request
    var query:URLQuery? { get }
    /// query string  when `body` exist
    var bodyQuery:URLQuery? { get }
}
extension HTTPParams{
    /// most time bodyQuery is nil
    public var bodyQuery:URLQuery? { nil }
}

///Use  application/json body
public typealias JSONParams = JSON
extension JSONParams:HTTPParams{
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

///`URLQuery` is also an `HTTPParams`. Use application/x-www-form-urlencoded body
public typealias URLParams = URLQuery
extension URLParams:HTTPParams{
    public var body: HTTPBody? {
        guard let data = encode()?.data(using: .utf8) else{
            return nil
        }
        return .urlencoded(data)
    }
    public var query: URLQuery?{ self }
}

///Standardized Plist params encoding
///
public struct PlistParams:HTTPParams,Sendable{
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
    public subscript(key:any JSONKey)->AnyValue{
        get { values[key] }
        set { values[key] = newValue}
    }
}
extension PlistParams:ExpressibleByArrayLiteral,ExpressibleByDictionaryLiteral{
    public init(arrayLiteral elements: Any?...) {
        self.values = .array(elements.map{ AnyValue($0) })
    }
    public init(dictionaryLiteral elements: (String,Any?)... ){
        self.values = .object(elements.reduce(into: [:], {
            $0[$1.0] = AnyValue($1.1)
        }))
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
    static func create(_ url:URL,method:Method,params:HTTPParams?,headers:Headers?,timeout:TimeInterval?)->URLRequest{
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
    static func query(_ url:URL,method:Method,query:URLQuery?,headers:Headers?,timeout:TimeInterval?)->URLRequest{
        var req = URLRequest(url:url , cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout ?? 0)
        if let headers{
            req.allHTTPHeaderFields = headers.values
        }
        req.httpMethod = method.rawValue
        if let query {
            req.addQuery(query)
        }
        return req
    }
}
