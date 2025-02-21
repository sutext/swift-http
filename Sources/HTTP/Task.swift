//
//  HTTPTask.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

/// `Request` is the common superclass of all request types and provides common state  and callback handling.
/// - Note provides progress interface for any request
class HTTPTask:@unchecked Sendable{
    private(set) var task:URLSessionTask
    @Safely private(set) var data: Data = Data()
    private let session:Session
    let promise:Promise<Data>
    init(
        _ task:URLSessionTask,
        session:Session,
        retrier:Retrier?){
        self.promise = .init()
        self.task = task
        self.session = session
        self.retrier  = retrier
    }
    /// some error if occured
    var error:Error?
    /// current retrier if present
    var retrier:Retrier?
    /// the metrics of current task
    var metrics:URLSessionTaskMetrics?
    /// the unique identifier of current request
    var id:Int { task.taskIdentifier }
    /// the original request url
    var url:String? { request?.url?.absoluteString }
    /// the current task state
    var state:URLSessionTask.State{ task.state }
    /// the current url request
    var request:URLRequest? { task.originalRequest }
    /// the total request duration in metrics
    var duration:TimeInterval? { metrics?.taskInterval.duration }
    /// the curren task progress
    var progress:Progress { task.progress }
    /// the current http url respone
    var response:HTTPURLResponse?{ task.response as? HTTPURLResponse }
    /// the current http status code
    var statusCode:Int?{  response?.statusCode  }
    /// the current http method
    var method:HTTP.Method? {
        guard let str = request?.httpMethod else {
            return nil
        }
        return .init(rawValue: str)
    }
    func resume()  {
        task.resume()
    }
    func cancel()  {
        task.cancel()
    }
    func suspend()  {
        task.suspend()
    }
    /// restart a task if completed.
    ///
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
    func finish(_ error:Error?)->(TimeInterval,URLRequest?)? {
        guard case .completed = state else {
            return nil
        }
        if let error{
            self.error = error
            return self.retry(when: error)
        }
        guard let resp = response else {
            let error = HTTP.Error.invalidResponse(resp: task.response)
            self.error = error
            return self.retry(when: error)
        }
        guard [200,204,205].contains(resp.statusCode) else {
            let error = HTTP.Error.invalidStatus(code:resp.statusCode)
            self.error = error
            return self.retry(when: error)
        }
        self.done()
        return nil
    }
    func retry(when error:Error)->(TimeInterval,URLRequest?)?{
        if let delay = self.retrier?.doRetry(self, when: error) {
            return (delay,nil)
        }
        guard let request else{
            self.done()
            return nil
        }
        do {
            let req = try session.network.restart(error: error, request: request)
            return (0,req)
        } catch  {
            self.error = error
            self.done()
            return nil
        }
    }
    func done(){
        if let error{
            self.promise.done(error,in: session.network.queue)
        }else{
            self.promise.done(data,in: session.network.queue)
        }
    }
    func cleanup(){
        
    }
}
class UploadTask:HTTPTask,@unchecked Sendable{
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
extension URLRequest{
    public mutating func setHeader(_ value:String,for field:Headers.Field){
        setValue(value, forHTTPHeaderField: field.rawValue)
    }
    public func header(for field:Headers.Field)->String?{
        value(forHTTPHeaderField: field.rawValue)
    }
}
public typealias FileTransfer = (_ tempURL:URL,_ response:HTTPURLResponse?) -> URL

class DownloadTask:HTTPTask,@unchecked Sendable{
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
    override func finish(_ error: Error?) -> (TimeInterval,URLRequest?)? {
        guard case .completed = state else {
            return nil
        }
        if let error{
            self.error = error
            return self.retry(when: error)
        }
        guard let resp = response else {
            let error = HTTP.Error.invalidResponse(resp: task.response)
            self.error = error
            return self.retry(when: error)
        }
        guard [200,204,205].contains(resp.statusCode) else {
            let error = HTTP.Error.invalidStatus(code:resp.statusCode)
            self.error = error
            return self.retry(when: error)
        }
        guard let location = self.fileURL?.absoluteString else {
            let error = HTTP.Error.download(info:"invalid destination file url")
            self.error = error
            return retry(when: error)
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
    override func cancel() {
        self.cancel(resumer: nil)
    }
    /// cancel a donwload task and get the resume data
    func cancel(resumer:((Data?)->Void)?){
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
