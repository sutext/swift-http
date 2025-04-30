//
//  Network.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

public protocol HTTPDelegate:AnyObject{
    /// Update the URLSessionConfiguration for network
    ///
    ///     func client(_ client:HTTPClient,shouldUpdate config:URLSessionConfiguration) {
    ///         config.httpShouldUsePipelining = true
    ///         config.timeoutIntervalForRequest = 60
    ///         config.timeoutIntervalForResource = 7*24*3600
    ///     }
    /// - Parameters:
    ///    - config:The internal default session config.
    ///    
    func client(_ client:HTTPClient,shouldUpdate config:URLSessionConfiguration)
    ///  A request hook function
    ///
    /// - Change the request params by return .rewrite(request).
    /// - Retrun a response directly by retrun .response(resp).
    /// - Return a error directly  by throws a new error.
    ///
    /// - Throws: return an error directly
    /// - Parameters:
    ///    - request: The original request
    /// - Returns: A `FilterResult` whtin none  rewrite or response
    ///
    /// - Note: All download tasks do not require filter
    ///
    func client(_ client:HTTPClient,modifyResult result:Result<Data,Error>,request:URLRequest,response:HTTPURLResponse)async throws->Result<Data,Error>
    /// A responsse hook function
    ///
    /// - Change the response by return new resultt
    /// - Change the error by throws a new error.
    ///
    /// - Throws: A new  Error to be response
    /// - Parameters:
    ///    - result: The original result
    ///    - request: The original request
    ///    - response: The original http  response
    /// - Returns: A new result
    /// - Note: All download tasks do not require verification
    ///
    func client(_ client:HTTPClient,filterRequest request:URLRequest)throws->FilterResult
    /// A responsse hook function
    ///
    /// - Return a new request for restart
    /// - Return `nil` for not restart
    ///
    /// - Throws: A new  Error to be response
    /// - Parameters:
    ///    - request: The original request
    ///    - error: The original error
    /// - Returns: A new `URLRequest` to be restart.
    /// - Note: All download tasks do not require retry mechanism
    ///
    func client(_ client:HTTPClient,restartRequest request:URLRequest,error:Error)async->URLRequest?
    
    /// Resolve the URLAuthenticationChallenge for the task.
    ///
    /// - Returns `ChallengeResult` for `urlSession:task:didReceive`
    func client(_ client:HTTPClient,task:URLSessionTask,didReceive challenge:Challenge)->ChallengeResult
}
/// Default `HTTPDelegate`  behavior
public extension HTTPDelegate{
    func client(_ client: HTTPClient, shouldUpdate config: URLSessionConfiguration) {
        
    }
    func client(_ client: HTTPClient, modifyResult result: Result<Data, any Error>, request: URLRequest, response: HTTPURLResponse) async throws -> Result<Data, any Error> {
        result
    }
    func client(_ client: HTTPClient, filterRequest request: URLRequest) throws -> FilterResult {
        .none
    }
    func client(_ client: HTTPClient, restartRequest request: URLRequest, error: any Error) async -> URLRequest? {
        nil
    }
    func client(_ client: HTTPClient, task: URLSessionTask, didReceive challenge: Challenge) -> ChallengeResult {
        .useDefault
    }
}

///
/// `HTTPClient` is network configure center.
///  Usually you can inherit from `HTTPClient` and override the configuration params .
///
open class HTTPClient:@unchecked Sendable{
    public init() { session.client = self }
    private let session:Session = Session()
    /// global baseURL for all request
    public var baseURL:String? = nil
    /// the http hocks and settings delegate
    public weak var delegate:HTTPDelegate?
    /// print debug log or not. override for custom
    public var debug:Bool = false
    /// global retryer  `nil` . Override it in  options
    public var retrier:Retrier? = nil
    /// global http headers `[:]`. Override it in  options
    public var headers:Headers = .default
    /// global timeout in secends `60`. Override it in  options
    public var timeout:TimeInterval = 60
    /// global fileManager. override for custom
    public var fileManager:FileManager = .default
    /// Cancel all the pening tasks except the download task
    public func cancelAllTask(){
        session.cancelAllTask()
    }
}
extension HTTPClient{
    ///
    /// Send an common data request
    ///
    /// - SeeAlso: `requesst(_:params:options:)`
    /// - Parameters:
    ///    - req: The `Request` protocol instance
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func request<R:Request>(_ req:R)->Response<R.Result>{
        let resp = _request(req.url,params: req.encode(),options: req.options).then { data in
            try await req.decode(data)
        }
        if debug{
            resp.debugPrint()
        }
        return resp
    }
    ///
    /// Send a simple data request directly
    ///
    /// - Parameters:
    ///    - url: The request url
    ///    - params: The request params
    ///    - options: The current request options
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func request(url:String,params:HTTPParams?=nil,options:Options = .get())->Response<Data>{
        let resp = _request(url,params: params,options: options)
        if debug{
            resp.debugPrint()
        }
        return resp
    }
   
    /// Send an file upload  request
    ///
    /// - SeeAlso: `upload(_:to:paramse:headers:timeout:)`
    /// - Parameters:
    ///    - req: The `UploadRequest` protocol instance
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func upload<R:UploadRequest>(_ req:R)->Response<R.Result>{
        let resp:Response<R.Result>
        switch req.upload{
        case .file(let fileURL):
            resp = _upload(fileURL, to: req.url,query: req.query,options: req.options).then {data in
                try await req.decode(data)
            }
        case .form(let data):
            resp = _upload(data, to: req.url,query: req.query,options: req.options).then {data in
                try await req.decode(data)
            }
        }
        if debug{
            resp.debugPrint()
        }
        return resp
    }
    /// Upload an local file  or form data to server.
    ///
    /// - Parameters:
    ///    - file: The fileURL to be upload
    ///    - to: The relative upload path
    ///    - parmas: The upload request params
    ///    - options: The upload request options
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func upload(
        _ file:URL,
        to url:String,
        query:URLQuery? = nil,
        options:Options = .post())->Response<Data>{
        let resp = _upload(file, to: url,query: query,options: options)
        if debug{
            resp.debugPrint()
        }
        return resp
    }
   
    /// Upload an local file to server.
    ///
    /// - Parameters:
    ///    - data: The  form data to be upload
    ///    - url: The relative upload path
    ///    - params: The upload request params
    ///    - headers: The upload request headers
    ///    - timeout: The request timeout
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func upload(
        _ data:FormData,
        to url:String,
        query:URLQuery? = nil,
        options:Options = .post())->Response<Data>{
        let resp = _upload(data, to: url,query: query,options: options)
        if debug{
            resp.debugPrint()
        }
        return resp
    }
    /// Creates an upload task from a resume data blob. Requires the server to support the latest resumable uploads
    /// Internet-Draft from the HTTP Working Group, found at
    /// https://datatracker.ietf.org/doc/draft-ietf-httpbis-resumable-upload/
    /// - If resuming from an upload file, the file must still exist and be unmodified. If the upload cannot be successfully
    /// resumed, URLSession:task:didCompleteWithError: will be called.
    /// - The resume data from the `URLError.uploadTaskResumeData` or `HTTPTask.cancel(resumer:)` must be save before yet.
    ///
    /// - Parameter data: Resume data blob from an incomplete upload, such as data returned by the cancelByProducingResumeData: method.
    /// - Returns: A new session upload task, or nil if the resumeData is invalid.
    @available(iOS 17.0,watchOS 10.0,macOS 14.0,tvOS 17.0, *)
    @discardableResult
    func upload(resume data:Data)->Response<Data>{
        self.session.upload(resume: data, fileManager: fileManager)
    }
    /// Send an file download  request
    ///
    /// - SeeAlso: `download(_:params:headers:timeout:transfer:)`
    /// - Parameters:
    ///    - req: The `DownloadRequest` protocol instance
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func download<R:DownloadRequest>(_ req:R)->Response<String>{
        self.download(req.url,query: req.query,options: req.options, transfer: req.transfer)
    }
    /// Send a simple download  request
    ///
    /// - Parameters:
    ///    - url: A full resource url
    ///    - params: The download request parameters
    ///    - headers: The download request headers
    ///    - transfer: The download file transfer
    /// - Returns: `Response<String>` A handler for task control and progress control. Response.Value is location of downloaded file
    ///
    /// - Note: If `transfer` is not specified, The download file will not be deleted until the system purges the temporary files. And the temporary file will been returned.
    ///
    @discardableResult
    public func download(
        _ url:String,
        query:URLQuery?=nil,
        options:Options = .get(),
        transfer:FileTransfer? = nil)->Response<String>{
        guard let url = URL(url, baseURL: options.baseURL ?? self.baseURL) else{
            return .init(HTTPError.invalidURL(url))
        }
        let timeout = options.timeout ?? self.timeout
        var headers = self.headers
        if let h = options.headers {
            headers.merge(h)
        }
        let urlreq = URLRequest.query(url,method: options.method,query: query, headers: headers, timeout: timeout)
        let resp = self.session.download(
            request: urlreq,
            retrier: options.retrier,
            fileManager: fileManager,
            transfer: transfer)
        if debug{
            resp.debugPrint()
        }
        return resp
    }
    /// Send a resume download request
    /// - Note: If `transfer` is not specified, the download will be moved to a temporary location determined by SwiftHTTP. The file will not be deleted until the system purges the temporary files.
    /// - Parameters:
    ///    - data: The resume data from `URLError.downloadTaskResumeData` or `HTTPTask.cancel(resumer:)`
    ///    - transfer: A closure used to determine how and where the downloaded file should be moved.
    ///    - completion: The data request completion call back
    /// - Returns: `Response<String>` A handler for task control and progress control. Response.Value is location of downloaded file
    ///
    @discardableResult
    public func download(resume data:Data,transfer:FileTransfer?=nil)->Response<String>{
        let resp = self.session.download(
            resume: data,
            fileManager: fileManager,
            transfer: transfer)
        if debug{
            resp.debugPrint()
        }
        return resp
    }
}
extension HTTPClient{
    private func _request(_  url:String,params:HTTPParams?,options:Options)->Response<Data>{
        guard let url = URL(url, baseURL: options.baseURL ?? self.baseURL) else{
            return .init(HTTPError.invalidURL(url))
        }
        let timeout = options.timeout ?? self.timeout
        var headers = self.headers
        if let h = options.headers {
            headers.merge(h)
        }
        let req = URLRequest.create(url, method: options.method,params: params, headers: headers, timeout: timeout)
        return self.session.request(req,retrier: options.retrier ?? self.retrier).map{
            guard let delegate = self.delegate else { return $0 }
            return try await delegate.client(self, modifyResult: $0, request: $1, response: $2)
        }
    }
    private func _upload(
        _ file:URL,
        to url:String,
        query:URLQuery?=nil,
        options:Options = .post())->Response<Data>
    {
        guard let url = URL(url, baseURL: options.baseURL ?? self.baseURL) else{
            return .init(HTTPError.invalidURL(url))
        }
        let timeout = options.timeout ?? self.timeout
        var headers = self.headers
        if let h = options.headers {
            headers.merge(h)
        }
        if headers[.contentType] == nil{
            headers[.contentType] = "application/octet-stream"
        }
        let urlreq = URLRequest.query(url,method: options.method,query: query, headers: headers, timeout: timeout)
        return self.session.upload(
            file: file,
            request: urlreq,
            retrier: options.retrier,
            fileManager: fileManager).map{
                guard let delegate = self.delegate else { return $0 }
                return try await delegate.client(self, modifyResult: $0, request: $1, response: $2)
            }
            
    }
    private func _upload(
        _ data:FormData,
        to url:String,
        query:URLQuery?=nil,
        options:Options = .post())->Response<Data>
    {
        guard let url = URL(url, baseURL: options.baseURL ?? self.baseURL) else{
            return .init(HTTPError.invalidURL(url))
        }
        let timeout = options.timeout ?? self.timeout
        var headers = self.headers
        if let h = options.headers {
            headers.merge(h)
        }
        headers[.contentType] = data.contentType
        let urlreq = URLRequest.query(url,method: options.method,query: query, headers: headers, timeout: timeout)
        return self.session.upload(
            form: data,
            request: urlreq,
            retrier: options.retrier,
            fileManager: fileManager).map{
                guard let delegate = self.delegate else { return $0 }
                return try await delegate.client(self, modifyResult: $0, request: $1, response: $2)
            }
    }
}
extension URL{
    /// build url safely
    init?(_ url:String,baseURL:String?){
        if url.hasPrefix("http"){ //Absolute URL
            self.init(string: url)
            return
        }
        guard let baseURL else{ //Relative URL must provide baseURL
            return nil
        }
        if baseURL.hasSuffix("/"){
            if url.hasPrefix("/"){
                self.init(string: "\(baseURL)\(url.dropFirst())")
            }else{
                self.init(string: "\(baseURL)\(url)")
            }
        }else{
            if url.hasPrefix("/"){
                self.init(string: "\(baseURL)\(url)")
            }else{
                self.init(string: "\(baseURL)/\(url)")
            }
        }
    }
}
/// Request verrify result
public enum FilterResult{
    /// Do not do anything
    case none
    /// replace original request
    case replace(URLRequest)
    /// return a response directly
    case response(Result<Data,Swift.Error>)
}
public typealias Challenge = URLAuthenticationChallenge
public enum ChallengeResult{
    /* The entire request will be canceled */
    case cancel
    /* This challenge is rejected and the next authentication protection space should be tried */
    case reject
    /* Default handling for the challenge - as if this delegate were not implemented; */
    case useDefault
    /* Use the specified credential */
    case useCredential(URLCredential)
}
extension URLCredential{
    public static func create(from p12File:String,key:String)->URLCredential?{
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: p12File)) else {
            return nil
        }
        return create(from: data, key: key)
    }
    public static func create(from p12Data:Data,key:String)->URLCredential?{
        let options = [kSecImportExportPassphrase as String: key]
        var rawItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData,options as CFDictionary,&rawItems)
        guard status == errSecSuccess else {
            return nil
        }
        guard let items = rawItems as? [[String:Any]] else{
            return nil
        }
        guard let item = items.first,
              let certs = item[kSecImportItemCertChain as String] as? [Any] else {
            return nil
        }
        let identity = item[kSecImportItemIdentity as String] as! SecIdentity
        return URLCredential(identity: identity, certificates: certs, persistence: .forSession)
    }
}
