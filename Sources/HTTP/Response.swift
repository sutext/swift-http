//
//  Response.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

extension DateFormatter{
    static let rfc822:DateFormatter = {
        let result = DateFormatter()
        result.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        result.locale = Locale(identifier: "en")
        result.timeZone = TimeZone(secondsFromGMT: 0)
        return result
    }()
}
extension HTTPURLResponse{
    public var timestamp:TimeInterval{
        if let datestr = allHeaderFields["Date"] as? String,
           let date = DateFormatter.rfc822.date(from: datestr){
            return date.timeIntervalSince1970
        }
        return Date().timeIntervalSince1970
    }
    public func header(for field:HTTP.Headers.Field)->String?{
        value(forHTTPHeaderField: field.rawValue)
    }
    public func header(for field:String)->String?{
        value(forHTTPHeaderField: field)
    }
}
public struct Response<Value:Sendable>:Sendable{
    private let promise:Promise<Value>
    /// The http task
    /// It will be nil when the request never been sent. At this case some error or some cached respone occurred
    public let task:HTTPTask?
    init(_ value:Value,task: HTTPTask? = nil){
        self.promise = .init(value)
        self.task = task
    }
    init(_ error:Error,task: HTTPTask? = nil){
        self.promise = .init(error)
        self.task = task
    }
    init(_ result:Result<Value,Error>,task: HTTPTask? = nil){
        self.promise = .init(result)
        self.task = task
    }
    init(_ promise: Promise<Value>, task: HTTPTask? = nil) {
        self.promise = promise
        self.task = task
    }
    /// internal map for modify result
    func map(_ onresult:@escaping @Sendable (Result<Value,Error>,URLRequest,HTTPURLResponse)async throws -> Result<Value,Error> ) -> Self{
        .init(promise.map({ r in
            if let request = self.task?.request,let response = self.task?.response{
                return try await onresult(r,request,response)
            }
            return r
        }), task: task)
    }
    /// - SeeAlso `Promise.map(:)`
    @discardableResult
    public func map<Other:Sendable>(_ onresult:@escaping @Sendable (Result<Value,Error>)async throws -> Result<Other,Error> ) -> Response<Other>{
        .init(promise.map(onresult), task: task)
    }
    /// - SeeAlso `Promise.then(:)`
    @discardableResult
    public func then<Other:Sendable>(_ onresolved:@escaping @Sendable (Value) async throws -> Other ) -> Response<Other>{
        .init(promise.then(onresolved), task: task)
    }
    /// - SeeAlso `Promise.catch(:)`
    @discardableResult
    public func `catch`(_ onrejected:@escaping @Sendable (Error) async throws -> Any? ) -> Self{
        .init(promise.catch(onrejected), task: task)
    }
    /// - SeeAlso `Promise.wait()`
    @discardableResult
    public func wait()async throws -> Value{
        try await promise.wait()
    }
    /// - SeeAlso `Promise.finally()`
    public func finally(_ handler:@escaping @Sendable (Result<Value,Error>)->Void ){
        promise.finally(handler)
    }
    public func cancel(){
        task?.cancel()
    }
    public func debugPrint(){
        promise.finally{ result in
            guard let task = self.task else{
                return
            }
            var body = ""
            if let contentType = task.request?.header(for: .contentType) {
                if contentType.contains("application/json") {
                    body = JSON(parse: task.request?.httpBody).description
                }else if contentType.contains("form-data"){
                    body = "multipart/form-data"
                }
            }
            print("""
            -----------------------DEUBG START--------------------------
            [\(task.method?.rawValue ?? "") URL]:  \(task.url ?? "None")
            [Request Data]: \(body)
            [Request Headers]: \(JSON(task.request?.allHTTPHeaderFields))
            [Request Duration]: \(task.duration ?? 0)s
            [Response Data]: \(JSON(task.data))
            [Response Result]: \(result)
            [Response Status]: \(task.statusCode ?? 0)
            [Response Headers]: \(JSON(task.response?.allHeaderFields))
            -----------------------DEUBG   END--------------------------
            """)
        }
    }
}
extension Response where Value == Data{
    init(_ task:HTTPTask){
        self.promise = task.promise
        self.task = task
    }
}
