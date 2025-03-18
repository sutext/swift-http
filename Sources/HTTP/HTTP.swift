//
//  HTTP.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation
@_exported import JSON
@_exported import Promise

///HTTP namespace
public enum HTTP{}

extension HTTP{
    ///HTTP request Errors
    public enum Error:Swift.Error{
        case encode(Swift.Error)
        case download(info:String)
        case invalidURL(url:String)
        case invalidParams(info:String)
        case invalidStatus(code:Int)
        case invalidResponse(resp:URLResponse?)
    }
    ///HTTP request methods
    public enum Method:String{
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
    
}

/// Request Parameters protocol
/// Do not declare new conformances to this protocol
/// they will not work as expected.
///
public protocol HTTPParams{
    var httpBody:Data?{ get }
}

///HTTP request Parameters
public typealias JSONParams = [String:any JSONValue]
extension JSONParams:HTTPParams{
    public var httpBody:Data? { try? JSONSerialization.data(withJSONObject: self) }
}

extension Array:HTTPParams where Element == JSONParams{
    public var httpBody:Data? { try? JSONSerialization.data(withJSONObject: self) }
}

extension JSON: HTTPParams{
    public var httpBody:Data?  {
        switch self {
        case .object(let object): // key-value
            let value = object.compactMapValues{ $0.compactValue }
            return try? JSONSerialization.data(withJSONObject: value)
        case .array(let array):// key-value array
            let value = array.compactMap { json in
                if case .object(let object) = self {
                    return object.compactMapValues{ $0.compactValue }
                }
                return nil
            }
            return try? JSONSerialization.data(withJSONObject: value)
        default:// simple value got nil
            return nil
        }
    }
}
