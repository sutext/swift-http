//
//  Network.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

public protocol HTTPDelegate:AnyObject{
    func client(_ client:HTTP.Client,couldUpdate session:URLSession)
    func client(_ client:HTTP.Client,modifyResult result:Result<Data,Error>,request:URLRequest,response:HTTPURLResponse)->Result<Data,Error>
    func client(_ client:HTTP.Client,fillterRequest request:URLRequest)->HTTP.FilterResult
    func client(_ client:HTTP.Client,restartRequest request:URLRequest,error:Error)->URLRequest
}
extension HTTP{
    ///
    /// `HTTP Client` is network configure center.
    ///  Usually you can inherit from `HTTP.Client` and override the configuration params .
    ///
    open class Client {
        private let session:Session = Session()
        public init(baseURL:String) {
            self.baseURL = URL(string:baseURL);
            session.client = self
        }
        public weak var delegate:HTTPDelegate?
        
        private var baseURL:URL?
        /// print debug log or not. override for custom
        open var debug:Bool{ false }
        /// global http method `.get` by default. override it in  options
        open var method:Method{.get}
        /// global retryer  `nil` by default .override it in  options
        open var retrier:Retrier?{ nil }
        /// global http headers `[:]` by default, override it in  options
        open var headers:Headers{ .default }
        /// global timeout in secends `60` by default. override it in  options
        open var timeout:TimeInterval{ 60 }
        /// global default fileManager. override for custom
        open var fileManager:FileManager{ .default }
        /// Update the URLSessionConfiguration for network
        ///
        /// - Parameters:
        ///    - config:The internal default session config.
        /// - Important: `override` this method to add your custom config
        ///
        ///     public override func update(config: URLSessionConfiguration) {
        ///         session.configuration.httpShouldUsePipelining = true
        ///         session.delegateQueue.maxConcurrentOperationCount
        ///     }
        open func update(session:URLSession) { }
        ///  request hook function
        ///
        /// - You can change the request params by return .rewrite(request).
        /// - You can retrun a response directly by retrun .response(resp).
        /// - You can return a error directly  by throws a new error.
        ///
        /// - Throws: return an error directly
        /// - Parameters:
        ///    - request: The original request
        /// - Returns: A `FilterResult` whtin none  rewrite or response
        ///
        /// - Note: All download tasks do not require filter
        ///
        open func filter(request:URLRequest)throws ->FilterResult{ .none }
        /// responsse hook function
        ///
        /// - You can change the response by return new resultt
        /// - You can change the error by throws a new error.
        /// - By default  hold the result
        ///
        /// - Throws: A new  Error to be response
        /// - Parameters:
        ///    - result: The original result
        ///    - request: The original request
        ///    - response: The original http  response
        /// - Returns: A new result
        /// - Note: All download tasks do not require verification
        ///
        open func modify(result:Result<Data,Swift.Error>,request:URLRequest,response:HTTPURLResponse)async throws -> Result<Data,Swift.Error>{
            result
        }
        /// .responsse hook function
        ///
        /// - You can return a new request for restart
        /// - You can change the error by throws a new error.
        /// - By default  hold the result
        ///
        /// - Throws: A new  Error to be response
        /// - Parameters:
        ///    - request: The original request
        ///    - error: The original error
        /// - Returns: A new `URLRequest` to be restart
        /// - Note: All download tasks do not require retry mechanism
        ///
        open func restart(request:URLRequest,error:Swift.Error)async throws ->URLRequest{ throw error }
        
        /// Resolve the URLAuthenticationChallenge for the task.
        ///
        /// - Returns `ChallengeResult` for `urlSession:task:didReceive`
        open func challenge(_ challenge:Challenge,for task:URLSessionTask)->ChallengeResult{
            .useDefault
        }
        /// Cancel all the padding task
        /// - Important： All download tasks are not canceled
        public func cancelAllTask(){
            session.cancelAllTask()
        }
    }
}
extension HTTP.Client{
    ///
    /// Send an common data request
    ///
    /// - SeeAlso: `requesst(_:params:options:)`
    /// - Parameters:
    ///    - req: The `Request` protocol instance
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func request<R:Request>(_ req:R)->Response<R.Model>{
        return self.request(req.path,params: req.params,options: req.options).then { data in
            try await req.convert(data)
        }
    }
    ///
    /// Send a simple data request directly
    ///
    /// - Parameters:
    ///    - path: The request relative to th baseURL
    ///    - params: The request params
    ///    - options: The current request options
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func request(_  path:String,params:HTTPParams?=nil,options:HTTP.Options?=nil)->Response<Data>{
        guard let baseURL = options?.baseURL ?? self.baseURL ,
              let url = URL(string:path,relativeTo:baseURL) else {
            return .init(HTTP.Error.invalidURL(url:path))
        }
        let method = options?.method ?? self.method
        let timeout = options?.timeout ?? self.timeout
        let retrier = options?.retrier ?? self.retrier
        var headers = self.headers
        if let h = options?.headers {
            headers.merge(h)
        }
        let urlreq = URLRequest.create(url, method: method,params: params, headers: headers, timeout: timeout)
        let resp = self.session.request(urlreq,retrier: retrier).map{
            try await self.modify(result: $0,request: $1, response: $2)
        }
        if debug{
            resp.debugPrint()
        }
        return resp
    }
    @discardableResult
    public func request(_ request:URLRequest)->Response<Data>{
        let resp = self.session.request(request,retrier: retrier).map{
            try await self.modify(result: $0,request: $1, response: $2)
        }
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
    public func upload<R:UploadRequest>(_ req:R)->Response<R.Model>{
        switch req.upload{
        case .file(let fileURL):
            return self.upload(fileURL, to: req.url,params: req.params,headers: req.headers,timeout: req.timeout).then {data in
                try await req.convert(data)
            }
        case .form(let data):
            return self.upload(data, to: req.url,params: req.params,headers: req.headers,timeout: req.timeout).then {data in
                try await req.convert(data)
            }
        }
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
        params:URLParams?=nil,
        headers:[String:String]?=nil,
        timeout:TimeInterval? = nil)->Response<Data>
    {
        guard let url = URL(string:url) else {
            return .init(HTTP.Error.invalidURL(url:url))
        }
        var h = self.headers
        if let headers{
            h.merge(headers)
        }
        if h[.contentType] == nil{
            h[.contentType] = "application/octet-stream"
        }
        let resp = self.session.upload(
            url,
            file: file,
            params: params,
            headers: h,
            timeout: timeout,
            fileManager: fileManager).map{
                try await self.modify(result: $0,request: $1, response: $2)
            }
        if debug{
            resp.debugPrint()
        }
        return resp
            
    }
    /// Upload an local file to server.
    ///
    /// - Parameters:
    ///    - data: The  form data to be upload
    ///    - to: The relative upload path
    ///    - parmas: The upload request params
    ///    - options: The upload request options
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func upload(
        _ data:FormData,
        to url:String,
        params:URLParams?=nil,
        headers:[String:String]?=nil,
        timeout:TimeInterval? = nil)->Response<Data>
    {
        guard let url = URL(string:url) else {
            return .init(HTTP.Error.invalidURL(url:url))
        }
        var h = self.headers
        if let headers{
            h.merge(headers)
        }
        let resp = self.session.upload(
            url,
            form: data,
            params: params,
            headers: h,
            timeout: timeout,
            fileManager: fileManager).map{
                try await self.modify(result: $0,request: $1, response: $2)
            }
        if debug{
            resp.debugPrint()
        }
        return resp
            
    }
    /// Send an file download  request
    ///
    /// - SeeAlso: `download(_:params:headers:timeout:transfer:)`
    /// - Parameters:
    ///    - req: The `DownloadRequest` protocol instance
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    @discardableResult
    public func download<R:DownloadRequest>(_ req:R)->Response<Data>{
        guard let url = URL(string:req.url) else {
            return .init(HTTP.Error.invalidURL(url:req.url))
        }
        let resp = self.session.download(
            url,
            params: req.params,
            headers: HTTP.Headers(req.headers),
            timeout: req.timeout,
            fileManager: fileManager,
            transfer:req.transfer)
        if debug{
            resp.debugPrint()
        }
        return resp
    }
    /// Send a simple download  request
    ///
    /// - Parameters:
    ///    - url: A full resource url
    ///    - params: The download request parameters
    ///    - headers: The download request headers
    ///    - transfer: The download file transfer
    /// - Returns: `Response<Data>` A handler for task control and progress control
    ///
    /// - Note: If `transfer` is not specified, The download file will not be deleted until the system purges the temporary files. And the temporary file will been returned.
    ///
    @discardableResult
    public func download(
        _ url:String,
        params:URLParams?=nil,
        headers:[String:String]?=nil,
        timeout:TimeInterval? = nil,
        transfer: FileTransfer? = nil)->Response<Data>
    {
        var aheaders = self.headers
        guard let url = URL(string:url) else {
            return .init(HTTP.Error.invalidURL(url:url))
        }
        if let newh = headers {
            aheaders.merge(newh)
        }
        let resp = self.session.download(
            url,
            params: params,
            headers: aheaders,
            timeout: timeout,
            fileManager: fileManager,
            transfer: transfer)
        if debug{
            resp.debugPrint()
        }
        return resp
    }
    /// Send a resume download request
    /// - Note: If `transfer` is not specified, the download will be moved to a temporary location determined by Airmey. The file will not be deleted until the system purges the temporary files.
    /// - Parameters:
    ///    - data: The resume data from a previously cancelled download request
    ///    - transfer: A closure used to determine how and where the downloaded file should be moved.
    ///    - completion: The data request completion call back
    /// - Returns: Thre request handler for task control and progress control
    ///
    @discardableResult
    public func download(resume data:Data, transfer: FileTransfer? = nil)->Response<Data>{
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

extension HTTP{
    /// Request verrify result
    public enum FilterResult{
        /// Do not do anything
        case none
        /// replace original request
        case replace(URLRequest)
        /// return a response directly
        case response(Result<Data,Swift.Error>)
    }
    public struct Options{
        /// overwrite the global method settings
        public var method:HTTP.Method?
        /// overwrite the global baseURL settings
        public var baseURL:URL?
        /// overwrite the global retrier settings
        public var retrier:Retrier?
        /// merge into global headers
        public var headers:[String:String]?
        /// overwrite global timeout settings
        public var timeout:TimeInterval?
        public init(
            _ method:HTTP.Method?=nil,
            baseURL:URL?=nil,
            retrier:Retrier?=nil,
            headers:[String:String]?=nil,
            timeout:TimeInterval?=nil) {
            self.method = method
            self.baseURL = baseURL
            self.retrier = retrier
            self.headers = headers
            self.timeout = timeout
        }
    }
}
extension HTTP{
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
