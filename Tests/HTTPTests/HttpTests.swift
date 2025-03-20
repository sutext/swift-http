import XCTest
@testable import HTTP

class Client:HTTP.Client,@unchecked Sendable{
    
}
let client = Client()

struct BaseURL:RawRepresentable,ExpressibleByStringLiteral{
    let rawValue:String
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    init(stringLiteral value: String) {
        self.rawValue = value
    }
    var url:URL?{ URL(string: rawValue) }
    static let baidu:BaseURL = "https://www.baidu.com"
}
struct BaiduRequest:Request,ExpressibleByStringLiteral{
    let path: String
    init(path: String) {
        self.path = path
    }
    var url: URL {
        URL(string: path,relativeTo: BaseURL.baidu.url)!
    }
    var params: HTTPParams?{ nil }
    var options: HTTP.Options? { nil }
    func decode(_ data: Data) async throws -> String {
        if let str = String(data: data, encoding: .utf8){
            return str
        }
        throw HTTP.Error.invalidResponse(resp: nil)
    }
    init(stringLiteral value: String) {
        self.path = value
    }
}
final class HttpTests: XCTestCase {
    func testExample() async throws {
//        Client.addStatus(observer: self, selector: #selector(statusChanged))
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let url = URL(string: "https://www.baidu.com")
        let url1 = URL(string: "/user/info")
        print(url?.absoluteString)
        print(url?.baseURL)
        print(url?.host)
        print(url?.path)
        print(url?.scheme)
        print(url1?.absoluteString)
        print(url1?.baseURL)
        print(url1?.host)
        print(url1?.path)
        print(url1?.scheme)
        let req:BaiduRequest = "/"
        print(try await client.request(req).wait())
    }
    
    @objc func statusChanged(){
//        print(Client.status)
    }
}
