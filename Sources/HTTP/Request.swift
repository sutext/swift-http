//
//  Request.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

public protocol Request{
    associatedtype Model:Sendable
    /// request url
    var url: String{ get }
    /// request params
    var params: HTTPParams?{ get }
    /// request options
    var options: HTTP.Options?{ get }
    /// model convert method
    func decode(_ data:Data)async throws ->Model
}
public enum Upload{
    case file(fileURL:URL)
    case form(data:FormData)
}
public protocol UploadRequest{
    associatedtype Model:Sendable
    /// request url
    var url: String{ get }
    /// request params
    var params: HTTPParams?{ get }
    /// request options
    var options: HTTP.Options?{ get }
    /// upload content
    var upload:Upload{ get }
    /// model convert method
    func decode(_ data:Data)async throws ->Model
}
public protocol DownloadRequest{
    /// full download url
    var url: String{ get }
    /// url params coding
    var params: URLParams?{ get }
    /// download optiions 
    var options: HTTP.Options?{ get }
    /// resolve download file location
    var transfer:FileTransfer?{ get }
}
