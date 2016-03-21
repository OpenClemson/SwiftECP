import Foundation
import Alamofire
import AEXML
import ReactiveCocoa
import XCGLogger

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
    return "Basic \(encodedUsernameAndPassword!)"
}

public func ECPLogin(
    protectedURL: NSURL,
    username: String,
    password: String,
    logger: XCGLogger? = nil
) -> SignalProducer<String, NSError> {
    return Alamofire.request(
        buildInitialSPRequest(protectedURL, log: logger)
    )
    .responseXML()
    .flatMap(.Concat) {
        sendIdpRequest(
            $0.value,
            username: username,
            password: password,
            log: logger
        )
    }
    .flatMap(.Concat) {
        sendFinalSPRequest(
            $0.0.value,
            idpRequestData: $0.1,
            log: logger
        )
    }
}
