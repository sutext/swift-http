//
//  Params.swift
//  HTTP
//
//  Created by supertext on 2025/3/19.
//

import Foundation

/// Description of http request parameters
/// Resolve body and query
public protocol HTTPParams:Sendable{
    /// http body data. Only exist in `post` `put` and so on
    /// Only one of the `query` and `body` will be encoded into the ur request
    var body:HTTPBody?{ get }
    /// URL-Encoded query string like `?key1=value1&key2=value2&key3[]=value4&key3[]=value5`
    /// Only exist in `get` `delete` `head` `conect`methods
    /// Only one of the `query` and `body` will be encoded into the url request
    var query:URLQuery? { get }
    /// URL-Encoded query string  even though `body` exist
    var bodyQuery:URLQuery? { get }
}
extension HTTPParams{
    /// At most time the bodyQuery is nil
    public var bodyQuery:URLQuery? { nil }
}
///Standardized JSON Params params encoding
@dynamicMemberLookup
public struct JSONParams:HTTPParams{
    private var json:JSON
    /// query params encoding
    public var query: URLQuery? {
        guard let object = json.object else{
            return nil
        }
        return URLQuery(object)
    }
    /// when application/json
    public var body: HTTPBody? {
        guard let data = json.compactData else{
            return nil
        }
        return .json(data)
    }
    public init(_ json:JSON = [:]) {
        self.json = json
    }
    public subscript(key:any JSONKey)->JSON{
        get { json[key] }
        set { json[key] = newValue}
    }
    public subscript(dynamicMember key:String)->JSON{
        get { json[key] }
        set { json[key] = newValue}
    }
}
extension JSONParams:ExpressibleByArrayLiteral,ExpressibleByDictionaryLiteral{
    public init(arrayLiteral elements: Any?...) {
        self.json = .array(elements.map{ AnyValue($0) })
    }
    public init(dictionaryLiteral elements: (String,Any?)... ){
        self.json = .object(elements.reduce(into: [:], {
            $0[$1.0] = JSON($1.1)
        }))
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

public struct HTTPBody:Sendable{
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
