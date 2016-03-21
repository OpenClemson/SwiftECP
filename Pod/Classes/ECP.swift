import Foundation
import Alamofire
import AEXML
import ReactiveCocoa
import XCGLogger

protocol ECPClient {
    func login(
        protectedURL: NSURL,
        username: String,
        password: String
    ) -> SignalProducer<String, NSError>
}

struct IdpRequestData {
    let request: NSMutableURLRequest
    let responseConsumerURL: NSURL
    let relayState: AEXMLElement?
}

func basicAuthHeader(username: String, password: String) -> String? {
    let encodedUsernameAndPassword = ("\(username):\(password)" as NSString)
        .dataUsingEncoding(NSASCIIStringEncoding)?
        .base64EncodedStringWithOptions([])
    guard encodedUsernameAndPassword != nil else {
        return nil
    }
    return "Basic \(encodedUsernameAndPassword)"
}

public class ECP: ECPClient {
    let log: XCGLogger?
	
	public init(logger: XCGLogger? = nil) {
        self.log = logger
	}

    public func login(
        protectedURL: NSURL,
        username: String,
        password: String
    ) -> SignalProducer<String, NSError> {
        let req = Alamofire.request(
            buildInitialSPRequest(protectedURL, log: log)
        )
        return req.responseXML()
            .flatMap(.Concat) { [weak self] in
                sendIdpRequest(
                    $0.value,
                    username: username,
                    password: password,
                    log: self?.log
                )
            }
            .flatMap(.Concat) { [weak self] in
                sendSpRequest(
                    $0.0.value,
                    idpRequestData: $0.1,
                    log: self?.log
                )
            }
    }
}