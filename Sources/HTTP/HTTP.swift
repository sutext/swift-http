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
extension Result{
    var error:Failure?{
        if case .failure(let err) = self {
            return err
        }
        return nil
    }
    var value:Success?{
        if case .success(let value) = self {
            return value
        }
        return nil
    }
}
///HTTP request Parameters
public typealias JSONParams = [String:JSONValue]

/// Request Parameters protocol
/// Do not declare new conformances to this protocol
/// they will not work as expected.
public protocol Parameters{
    var contentType:String?{ get }
    func bodyData()throws->Data
}
extension JSONParams:Parameters{
    public var contentType: String?{
        "application/json"
    }
    public func bodyData() throws -> Data {
        try JSONSerialization.data(withJSONObject: self)
    }
}
extension Array:Parameters where Element == JSONParams{
    public var contentType: String?{
        "application/json"
    }
    public func bodyData() throws -> Data {
        try JSONSerialization.data(withJSONObject: self)
    }
}
