//
//  Network.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

extension HTTP{
    ///
    /// `HTTP Client` is network configure center.
    ///  Usually you can inherit from `HTTP.Client` and override the configuration params .
    ///
    open class Client {
        private let session:Session = Session()
        public init(baseURL:String) {
            self.baseURL = URL(string:baseURL);
            session.network = self
        }
        private var baseURL:URL?
        /// print debug log or not. override for custom
        open var debug:Bool{ false }
        /// global callback queue by default use main queue.
        open var queue:DispatchQueue { .main }
        /// global http method `.get` by default. override it in  options
        open var method:HTTP.Method{.get}
        /// global retryer  `nil` by default .override it in  options
        open var retrier:Retrier?{ nil }
        /// global http headers `[:]` by default, override it in  options
        open var headers:[String:String]{ [:] }
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
        /// - Yout can `override` it by custom filter in options.
        /// - You can change the request params by return .rewrite(request).
        /// - You can retrun a response directly by retrun .response(resp).
        /// - You can return a error directly  by throws a new error.
        ///
        /// - Throws: return an error directly
        /// - Parameters:
        ///    - req: The original request
        /// - Returns: A `FilterResult` whtin none  rewrite or response
        /// - Important: All download tasks are not filtered
        ///
        open func filter(request:URLRequest)throws ->FilterResult{ .none }
        /// .responsse hook function
        ///
        /// - Yout can `override` it by custom verifier in options.
        /// - You can change the response data by return .rewrite(data).
        /// - You can change the error by throws a new error.
        /// - You restart current task by retrun .restart(URLRequest).
        ///
        /// - Throws: A new Response Error
        /// - Parameters:
        ///    - resp: The input Response
        /// - Returns: A `VerifyResult` whtin none restart and rewrite.
        /// - Important: All download tasks are not verified
        ///
        open func restart(error:Swift.Error,request:URLRequest)throws ->URLRequest{ throw error }
        
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
    /// - Parameters:
    ///    - req: The `AMRequest` protocol instance
    /// - Returns: Thre request handler for task control and progress control
    ///
    @discardableResult
    public func request<R:Request>(_ req:R)->Response<R.Model>{
        guard let baseURL = req.options?.baseURL ?? self.baseURL ,
              let url = URL(string:req.path,relativeTo:baseURL) else {
            return .init(HTTP.Error.invalidURL(url:req.path))
        }
        let method = req.options?.method ?? self.method
        let timeout = req.options?.timeout ?? self.timeout
        let retrier = req.options?.retrier ?? self.retrier
        var headers = Headers(self.headers)
        if let h = req.options?.headers {
            headers.merge(h)
        }
        let result = HTTPEncoder.encode(url, method: method, params: req.params, headers: headers, timeout: timeout)
        guard let urlreq = result.value else{
            return .init(HTTP.Error.encode(result.error!))
        }
        let resp = self.session.request(urlreq,retrier: retrier).then{ data in
            try req.convert(data)
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
    ///    - path: The request relative to th baseURL
    ///    - params: The request params
    ///    - options: The current request options
    /// - Returns: Thre request handler for task control and progress control
    ///
    @discardableResult
    public func request(_  path:String,params:Parameters?=nil,options:HTTP.Options?=nil)->Response<Data>{
        guard let baseURL = options?.baseURL ?? self.baseURL ,
              let url = URL(string:path,relativeTo:baseURL) else {
            return .init(HTTP.Error.invalidURL(url:path))
        }
        let method = options?.method ?? self.method
        let timeout = options?.timeout ?? self.timeout
        let retrier = options?.retrier ?? self.retrier
        var headers = Headers(self.headers)
        if let h = options?.headers {
            headers.merge(h)
        }
        let result = HTTPEncoder.encode(url, method: method, params: params, headers: headers, timeout: timeout)
        guard let urlreq = result.value else{
            return .init(HTTP.Error.encode(result.error!))
        }
        let resp = self.session.request(urlreq,retrier: retrier)
        if debug{
            resp.debugPrint()
        }
        return resp
    }
    /// Send an file upload  request
    ///
    /// - Parameters:
    ///    - req: The `AMFileUpload` protocol instance
    ///    - completion: The data request completion call back
    /// - Returns: Thre request handler for task control and progress control
    ///
    @discardableResult
    public func upload<R:UploadRequest>(_ req:R)->Response<R.Model>{
        guard let url = URL(string:req.url) else {
            return .init(HTTP.Error.invalidURL(url:req.url))
        }
        var headers = Headers(self.headers)
        if let h = req.headers {
            headers.merge(h)
        }
        let resp:Response<R.Model>
        switch req.upload{
        case .file(let fileURL):
            if headers[.contentType] == nil{
                headers[.contentType] = "application/octet-stream"
            }
            resp = self.session.upload(
                url,
                file: fileURL,
                params: req.params,
                headers: headers,
                timeout: req.timeout,
                fileManager: fileManager).then { data in
                    try req.convert(data)
                }
        case .form(let data):
            resp = self.session.upload(
                url,
                form: data,
                params: req.params,
                headers: headers,
                timeout:req.timeout,
                fileManager: fileManager).then { data in
                    try req.convert(data)
                }
        }
        if debug{
            resp.debugPrint()
        }
        return resp
    }
    /// Upload an local file to server.
    ///
    /// - Parameters:
    ///    - file: The fileURL to be upload
    ///    - to: The relative upload path
    ///    - parmas: The upload request params
    ///    - options: The upload request options
    ///    - completion: The data request completion call back
    /// - Returns: Thre request handler for task control and progress control
    ///
    @discardableResult
    public func upload(
        _ file:URL,
        to url:String,
        params:JSONParams?=nil,
        headers:[String:String]?=nil,
        timeout:TimeInterval? = nil)->Response<Data>
    {
        guard let url = URL(string:url) else {
            return .init(HTTP.Error.invalidURL(url:url))
        }
        var h = Headers(self.headers)
        if let headers{
            h.merge(headers)
        }
        let resp = self.session.upload(
            url,
            file: file,
            params: params,
            headers: h,
            timeout: timeout,
            fileManager: fileManager)
        if debug{
            resp.debugPrint()
        }
        return resp
            
    }
    /// Send an file download  request
    /// - Note: If `transfer` is not specified, The download file will not be deleted until the system purges the temporary files. And the temporary file will been returned.
    /// - Parameters:
    ///    - req: The `AMDownload` protocol instance
    ///    - completion: Call back the transfered file location.
    /// - Returns: Thre request handler for task control and progress control
    ///
    @discardableResult
    public func download<R:DownloadRequest>(_ req:R)->Response<Data>{
        guard let url = URL(string:req.url) else {
            return .init(HTTP.Error.invalidURL(url:req.url))
        }
        let resp = self.session.download(
            url,
            params: req.params,
            headers: Headers(req.headers),
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
    ///    - completion: Call back the temporary file location. At this time transfer not suport
    /// - Returns: Thre request handler for task control and progress control
    ///
    @discardableResult
    public func download(
        _ url:String,
        params:JSONParams?=nil,
        headers:[String:String]?=nil,
        timeout:TimeInterval? = nil,
        transfer: FileTransfer? = nil)->Response<Data>
    {
        var aheaders = Headers(self.headers)
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
