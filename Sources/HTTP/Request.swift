//
//  Request.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

public protocol Request{
    associatedtype Model:Sendable
    /// relative request url
    var path: String{get}
    /// request params
    var params: Parameters?{get}
    /// request options
    var options: HTTP.Options?{get}
    /// model convert method
    func convert(_ data:Data)async throws ->Model
}
public enum Upload{
    case file(fileURL:URL)
    case form(data:FormData)
}
public protocol UploadRequest{
    associatedtype Model:Sendable
    /// relative request url
    var url: String{get}
    /// request params
    var params: JSONParams?{get}
    /// uplload content
    var upload:Upload{get}
    /// http headers
    var headers:[String:String]?{get}
    /// upload timeout
    var timeout:TimeInterval?{get}
    /// model convert method
    func convert(_ data:Data)async throws ->Model
    
}
public protocol DownloadRequest{
    /// full download url
    var url: String{get}
    /// url params coding
    var params: JSONParams?{get}
    /// http headers
    var headers: [String:String]?{get}
    /// download timeout
    var timeout:TimeInterval?{get}
    /// resolve download file location
    var transfer:FileTransfer?{get}
    
}
