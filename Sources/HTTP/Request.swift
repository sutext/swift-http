//
//  Request.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

public protocol Request{
    associatedtype Result:Sendable
    associatedtype Params:HTTPParams
    /// It can be a full URL or a relative URL
    var url:String{ get }
    /// get the http params
    var params:Params{ get }
    /// request options
    var options:Options{ get }
    /// decode response data to Result modle
    func decode(_ data:Data)async throws ->Result
}
///Standardized JSON data  Request
@frozen public struct JSONRequest:Request,Sendable{
    public var url: String
    public var params: JSONParams
    public var options: Options
    public init(_ url: String, params: JSONParams = [:], options: Options = .get()) {
        self.url = url
        self.params = params
        self.options = options
    }
    public func decode(_ data: Data) async throws -> JSON {
        try JSON.parse(data)
    }
}
extension JSONRequest:ExpressibleByStringLiteral{
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

@frozen public enum Upload:Sendable{
    case file(url:URL)
    case form(data:FormData)
}
public protocol UploadRequest{
    associatedtype Result:Sendable
    /// request url
    var url: String{ get }
    /// url query parameters
    var query: URLQuery?{ get }
    /// upload content
    var upload: Upload{ get }
    /// upload options
    var options: Options{ get }
    /// model convert method
    func decode(_ data:Data)async throws ->Result
}

public protocol DownloadRequest{
    /// full download url
    var url: String{ get }
    /// url query parameters
    var query: URLQuery?{ get }
    /// download options
    var options: Options{ get }
    /// resolve download file location
    var transfer: FileTransfer?{ get }
}

