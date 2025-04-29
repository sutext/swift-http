//
//  Session.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Foundation

class Session:NSObject{
    @Safely private var tasks:[Int:HTTPTask] = [:]
    private let rootQueue:DispatchQueue = DispatchQueue(label: "SwiftHTTP.root.\(UInt.random(in: 100000...199999))",attributes: .concurrent)
    lazy var session:URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldUsePipelining = true
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 6
        queue.underlyingQueue = rootQueue
        queue.qualityOfService = .default
        client.delegate?.client(client, shouldUpdate: config)
        let session = URLSession(configuration: config,delegate: self,delegateQueue: queue)
        return session
    }()
    weak var client:HTTPClient!
    func request(_ req:URLRequest, retrier:Retrier?)->Response<Data>{
        do {
            var urlreq = req
            let fr = try self.client.delegate?.client(client, filterRequest: urlreq)
            switch fr{
            case .response(let resp):
                return .init(resp)
            case .replace(let newreq):
                urlreq = newreq
            default:
                break
            }
            let task = self.session.dataTask(with: urlreq)
            let req = HTTPTask(task,session: self,retrier: retrier)
            self.add(req)
            return .init(req)
        } catch {
            return .init(error)
        }
    }
    func upload(
        file:URL,
        request:URLRequest,
        retrier:Retrier?,
        fileManager:FileManager)->Response<Data>
    {
        do {
            var urlreq = request
            let fr = try self.client.delegate?.client(client, filterRequest: urlreq)
            switch fr{
            case .response(let resp):
                return .init(resp)
            case .replace(let newreq):
                urlreq = newreq
            default:
                break
            }
            let task = self.session.uploadTask(with: urlreq, fromFile: file)
            let req = UploadTask(task,session: self,retrier: retrier,fileManager: fileManager)
            self.add(req)
            return .init(req)
        } catch {
            return .init(error)
        }
    }
    func upload(
        form:FormData,
        request:URLRequest,
        retrier:Retrier?,
        fileManager:FileManager)->Response<Data>
    {
        do {
            var urlreq = request
            let fr = try self.client.delegate?.client(client, filterRequest: request)
            switch fr{
            case .response(let resp):
                return .init(resp)
            case .replace(let newreq):
                urlreq = newreq
            default:
                break
            }
            let upload = try form.toUpload()
            var req:UploadTask
            switch upload {
            case .data(let data):
                let task = self.session.uploadTask(with: urlreq, from: data)
                req = UploadTask(task,session: self,retrier: retrier,fileManager: form.fileManager)
            case .file(let fileURL):
                let task = self.session.uploadTask(with: urlreq, fromFile: fileURL)
                req = UploadTask(task,session: self,retrier: retrier,fileManager: form.fileManager)
                req.tempFile = fileURL
            }
            self.add(req)
            return .init(req)
        } catch {
            return .init(error)
        }
    }
    @available(iOS 17.0,watchOS 10.0,macOS 14.0,tvOS 17.0, *)
    func upload(resume data:Data,fileManager:FileManager)->Response<Data>{
        let task = self.session.uploadTask(withResumeData: data)
        let req = UploadTask(task, session: self,retrier: nil, fileManager: fileManager)
        self.add(req)
        return .init(req)
    }
    func download(
        resume data: Data,
        fileManager:FileManager,
        transfer:FileTransfer?)->Response<String>
    {
        let task = self.session.downloadTask(withResumeData: data)
        let req = DownloadTask(task,session: self,retrier: nil,transfer: transfer, fileManager: fileManager)
        self.add(req)
        return Response(req).then { data in
            guard let location = String(data:data,encoding: .utf8) else{
                throw HTTPError.downloadFileNotFound
            }
            return location
        }
    }
    func download(
        request:URLRequest,
        retrier:Retrier?,
        fileManager:FileManager,
        transfer:FileTransfer?)->Response<String>
    {
        let task = self.session.downloadTask(with: request)
        let req = DownloadTask(task,session: self,retrier: retrier ,transfer: transfer, fileManager: fileManager)
        self.add(req)
        return Response(req).then { data in
            guard let location = String(data:data,encoding: .utf8) else{
                throw HTTPError.downloadFileNotFound
            }
            return location
        }
    }
}

extension Session{
    func cancelAllTask(){
        self.$tasks.read { ts in
            ts.forEach {
                if !($0.value is DownloadTask){
                    $0.value.cancel()
                }
            }
        }
    }
    func add(_ task:HTTPTask) {
        self.$tasks[task.id] = task
        task.resume()
    }
    func remove(_ task:HTTPTask){
        self.$tasks[task.id] = nil
    }
}
extension Session:URLSessionTaskDelegate{
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        if let req = self.$tasks[task.taskIdentifier] {
            req.metrics = metrics
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let task = self.$tasks[task.taskIdentifier],
              let result = self.client.delegate?.client(self.client, task: task.task, didReceive: challenge) else{
            completionHandler(.performDefaultHandling,nil)
            return
        }
        switch result {
        case .useDefault:
            completionHandler(.performDefaultHandling,nil)
        case .reject:
            completionHandler(.rejectProtectionSpace,nil)
        case .cancel:
            completionHandler(.cancelAuthenticationChallenge,nil)
        case .useCredential(let credential):
            completionHandler(.useCredential,credential)
        }
    }
}
extension Session:URLSessionDataDelegate{
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let req = self.$tasks[dataTask.taskIdentifier] else{ return }
        if req is DownloadTask{ return }
        req.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let req = self.$tasks[task.taskIdentifier] else{ return }
        self.remove(req)
        Task{
            if let retry = await req.finish(error) {
                self.rootQueue.asyncAfter(deadline: .now()+retry.0) {
                    req.restart(req:retry.1)
                }
            }else{
                req.cleanup()
            }
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    }
}

extension Session : URLSessionDownloadDelegate{
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL){
        if let req = self.$tasks[downloadTask.taskIdentifier] as? DownloadTask{
            req.finishDownload(location)
        }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64){

    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64){
        
    }
}
