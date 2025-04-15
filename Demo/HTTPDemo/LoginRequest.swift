//
//  LoginRequest.swift
//  HTTPDemo
//
//  Created by supertext on 2025/4/8.
//
import HTTP
import Foundation
import SwiftProtobuf


extension Message{
    public var body: HTTPBody?{
        guard let data = try? serializedData() else{
            return nil
        }
        return .protobuf(data)
    }
    public var query: URLQuery? { nil }
}

extension LoginParams:HTTPParams{}

class PBRequest<Req:Message&HTTPParams,Resp:Message>:Request{
    let url: String
    var options: Options? = .post()
    var params:Req = .init()
    var parameters: HTTPParams?{ params }
    func decode(_ data: Data) async throws -> Resp {
        try Resp.init(serializedBytes: data)
    }
    init(url: String) {
        self.url = url
    }
}
class LoginRequest:PBRequest<LoginParams,LoginInfo>{
    init(username: String,password:String) {
        super.init(url: "/login")
        self.params.username = username
        self.params.password = password
    }
}
