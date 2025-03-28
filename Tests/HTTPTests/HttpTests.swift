import XCTest
@testable import HTTP

class Client:HTTP.Client,@unchecked Sendable{
    override init() {
        super.init()
        self.baseURL = URL(string: "https://www.baidu.com")
        self.debug = true
        self.delegate = self
    }
}
extension Client:HTTPDelegate{
    func client(_ client: HTTP.Client, shouldUpdate config: URLSessionConfiguration) {
        
    }
    
    func client(_ client: HTTP.Client, modifyResult result: Result<Data, any Error>, request: URLRequest, response: HTTPURLResponse) async throws -> Result<Data, any Error> {
        result
    }
    
    func client(_ client: HTTP.Client, fillterRequest request: URLRequest) throws -> HTTP.FilterResult {
        .none
    }
    
    func client(_ client: HTTP.Client, restartRequest request: URLRequest, error: any Error) async throws -> URLRequest {
        throw error
    }
    
    func client(_ client: HTTP.Client, task: URLSessionTask, didReceive challenge: HTTP.Challenge) -> HTTP.ChallengeResult {
        .useDefault
    }
}

let client = Client()
struct JSONRequest:Request,ExpressibleByStringLiteral{
    var params:JSON = [:]
    var options: HTTP.Options? = .init(.get)
    var url: String{ path }
    var parameters:HTTPParams?{ params }
    
    let path: String
    init(path: String) {
        self.path = path
    }
    func decode(_ data: Data) async throws -> String {
        String(data:data,encoding: .utf8) ?? ""
    }
    init(stringLiteral value: StringLiteralType) {
        self.init(path: value)
    }
}
final class HttpTests: XCTestCase {
    func testGet() async throws {
        let req:JSONRequest = "/"
        print(try await client.request(req).wait())
    }
    
    @objc func statusChanged(){
//        print(Client.status)
    }
}
