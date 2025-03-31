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
    var options: HTTP.Options?{ get }
    /// request params
    var parameters: HTTPParams?{ get }
    /// model convert method
    func decode(_ data:Data)async throws ->Result
}
public extension Request{
    var options:HTTP.Options? { nil  }
    var parameters:HTTPParams? { nil  }
}
public enum Upload{
    case file(fileURL:URL)
    case form(data:FormData)
}
public protocol UploadRequest{
    associatedtype Result:Sendable
    /// request url
    var url: String{ get }
    /// request options
    var options: HTTP.Options?{ get }
    /// upload content
    var upload:Upload{ get }
    /// url query parameters
    var parameters: URLParams?{ get }
    /// model convert method
    func decode(_ data:Data)async throws ->Result
}
public extension UploadRequest{
    var options:HTTP.Options? { nil  }
    var parameters:HTTPParams? { nil  }
}
public protocol DownloadRequest{
    /// full download url
    var url: String{ get }
    /// download optiions 
    var options: HTTP.Options?{ get }
    /// resolve download file location
    var transfer:FileTransfer?{ get }
    /// url query parameters
    var parameters: URLParams?{ get }
}
public extension DownloadRequest{
    var options:HTTP.Options? { nil  }
    var transfer:FileTransfer?{ nil }
    var parameters:HTTPParams? { nil  }
}
