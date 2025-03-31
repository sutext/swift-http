//
//  HTTPTask.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

extension URLRequest{
    public var method:HTTP.Method?{
        guard let httpMethod else {
            return nil
        }
        return .init(rawValue: httpMethod)
    }
    public mutating func setHeader(_ value:String,for field:HTTP.Headers.Field){
        setValue(value, forHTTPHeaderField: field.rawValue)
    }
    public func header(for field:HTTP.Headers.Field)->String?{
        value(forHTTPHeaderField: field.rawValue)
    }
    public func header(for field:String)->String?{
        value(forHTTPHeaderField: field)
    }
}
public class HTTPTask:@unchecked Sendable{
    private let session:Session
    private(set) var task:URLSessionTask
    @Safely private(set) var data: Data = Data()
    /// some error if occured
    var error:Error?
    let promise:Promise<Data>
    init(
        _ task:URLSessionTask,
        session:Session,
        retrier:HTTP.Retrier?){
        self.promise = .init()
        self.task = task
        self.session = session
        self.retrier  = retrier
    }
    /// current retrier if present
    public var retrier:HTTP.Retrier?
    /// the metrics of current task
    public var metrics:URLSessionTaskMetrics?
    /// the unique identifier of current request
    public var id:Int { task.taskIdentifier }
    /// the original request url
    public var url:String? { request?.url?.absoluteString }
    /// the current task state
    public var state:URLSessionTask.State{ task.state }
    /// the current url request
    public var request:URLRequest? { task.originalRequest }
    /// the total request duration in metrics
    public var duration:TimeInterval? { metrics?.taskInterval.duration }
    /// the curren task progress
    public var progress:Progress { task.progress }
    /// the current http url respone
    public var response:HTTPURLResponse?{ task.response as? HTTPURLResponse }
    /// the current http status code
    public var statusCode:Int?{  response?.statusCode  }
    /// the current http method
    public var method:HTTP.Method? {
        request?.method
    }
    public func resume()  {
        task.resume()
    }
    public func cancel()  {
        task.cancel()
    }
    public func suspend()  {
        task.suspend()
    }
    func restart(req:URLRequest? = nil) {
        guard case .completed = state else{
            return
        }
        guard let req = req ?? task.originalRequest else {
            return
        }
        self.data = Data()
        self.metrics = nil
        self.error = nil
        self.task = self.session.session.dataTask(with: req)
        self.session.add(self)
    }
    func append(_ data:Data) {
        self.$data.write {
            $0.append(data)
        }
    }
    func finish(_ error:Error?)async->(TimeInterval,URLRequest?)? {
        guard case .completed = state else {
            return nil
        }
        if let error{
            self.error = error
            return await self.retry(when: error)
        }
        guard let resp = response else {
            let error = HTTP.Error.invalidResponse(resp: task.response)
            self.error = error
            return await self.retry(when: error)
        }
        guard [200,204,205].contains(resp.statusCode) else {
            let error = HTTP.Error.invalidStatus(code:resp.statusCode)
            self.error = error
            return await self.retry(when: error)
        }
        self.done()
        return nil
    }
    func retry(when error:Error) async->(TimeInterval,URLRequest?)?{
        if let delay = self.retrier?.doRetry(self, when: error) {
            return (delay,nil)
        }
        guard let request else{
            self.done()
            return nil
        }
        guard let delegate = self.session.client.delegate else{
            self.done()
            return nil
        }
        do {
            let req = try await delegate.client(self.session.client, restartRequest: request, error: error)
            return (0,req)
        } catch  {
            self.error = error
            self.done()
            return nil
        }
    }
    func done(){
        if let error{
            self.promise.done(error)
        }else{
            self.promise.done(data)
        }
    }
    func cleanup(){
        
    }
}
public class UploadTask:HTTPTask,@unchecked Sendable{
    private var fileManager:FileManager
    /// temp file when multipart/form-data
    var tempFile:URL?
    init(
        _ task: URLSessionTask,
        session:Session,
        fileManager: FileManager) {
        self.fileManager = fileManager
        super.init(task,session: session, retrier: nil)
    }
    override func cleanup() {
        super.cleanup()
        if let url = tempFile {
            try? fileManager.removeItem(at: url)
        }
    }
}

public typealias FileTransfer = (_ tempURL:URL,_ response:HTTPURLResponse?) -> URL

public class DownloadTask:HTTPTask,@unchecked Sendable{
    /// temp file url transfer
    private var fileManager:FileManager
    private let transfer:FileTransfer
    private var fileURL:URL?
    init(
        _ task: URLSessionDownloadTask,
        session: Session,
        transfer: FileTransfer?,
        fileManager:FileManager) {
        self.transfer = transfer ?? {url,_ in
            let filename = "SwiftHTTP_\(url.lastPathComponent)"
            let destination = url.deletingLastPathComponent().appendingPathComponent(filename)
            return destination
        }
        self.fileManager = fileManager
        super.init(task, session: session,retrier: nil)
    }
    override func finish(_ error: Error?)async -> (TimeInterval,URLRequest?)? {
        guard case .completed = state else {
            return nil
        }
        if let error{
            self.error = error
            return await self.retry(when: error)
        }
        guard let resp = response else {
            let error = HTTP.Error.invalidResponse(resp: task.response)
            self.error = error
            return await self.retry(when: error)
        }
        guard [200,204,205].contains(resp.statusCode) else {
            let error = HTTP.Error.invalidStatus(code:resp.statusCode)
            self.error = error
            return await self.retry(when: error)
        }
        guard let location = self.fileURL?.absoluteString else {
            let error = HTTP.Error.invalidDownloadFile
            self.error = error
            return await retry(when: error)
        }
        
        self.append(location.data(using: .utf8)!)
        self.done()
        return nil
    }
    func finishDownload(_ location:URL){
        let destination = transfer(location,response)
        do {
            try? fileManager.removeItem(at: destination)
            let directory = destination.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.moveItem(at: location, to: destination)
            self.fileURL = destination
        } catch {
            self.error = error
        }
    }
    /// cancel dirctly without resume data
    override public func cancel() {
        self.cancel(resumer: nil)
    }
    /// cancel a donwload task and get the resume data
    public func cancel(resumer:((Data?)->Void)?){
        guard task.state != .completed else {
            return
        }
        guard let task = task as? URLSessionDownloadTask else {
            return
        }
        guard let block = resumer else {
            task.cancel { _ in }
            return
        }
        task.cancel(byProducingResumeData: block)
    }
}
