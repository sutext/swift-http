//
//  Request.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

public protocol Request{
    associatedtype Result:Sendable
    /// request url
    var url: String{ get }
    /// request options
    var options: Options?{ get }
    /// request params
    var parameters: HTTPParams?{ get }
    /// model convert method
    func decode(_ data:Data)async throws ->Result
}
///Standardized JSON data  Request
public struct JSONRequest:Request,Sendable{
    public var url: String
    public var options: Options?
    public var params:JSONParams
    public init(url: String, options: Options? = nil, params: JSONParams = [:]) {
        self.url = url
        self.options = options
        self.params = params
    }
    public var parameters:HTTPParams?{
        params
    }
    public func decode(_ data: Data) async throws -> JSON {
        try JSON.parse(data)
    }
}
extension JSONRequest:ExpressibleByStringLiteral{
    public init(stringLiteral value: String) {
        self.init(url: value)
    }
}
public enum Upload:Sendable{
    case file(fileURL:URL)
    case form(data:FormData)
}
public protocol UploadRequest{
    associatedtype Result:Sendable
    /// request url
    var url: String{ get }
    /// url query parameters
    var query: URLQuery?{ get }
    /// upload content
    var upload:Upload{ get }
    /// request options
    var options: Options?{ get }
    /// model convert method
    func decode(_ data:Data)async throws ->Result
}

public protocol DownloadRequest{
    /// full download url
    var url: String{ get }
    /// url query parameters
    var query: URLQuery?{ get }
    /// download optiions
    var options: Options?{ get }
    /// resolve download file location
    var transfer:FileTransfer?{ get }

}

