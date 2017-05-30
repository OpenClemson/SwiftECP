import AEXML_CU
import Alamofire
import AnyError
import XCGLogger
import Foundation
import ReactiveSwift

struct IdpRequestData {
    let request: URLRequest
    let responseConsumerURL: URL
    let relayState: AEXMLElement?
}

public func ECPLogin(
    protectedURL: URL,
    username: String,
    password: String,
    logger: XCGLogger? = nil
    ) -> SignalProducer<String, AnyError> {
    return Alamofire.request(
        buildInitialSPRequest(protectedURL: protectedURL, log: logger)
    )
    .responseXML()
    .flatMap(.concat) {
        sendIdpRequest(
            initialSpResponse: $0.value,
            username: username,
            password: password,
            log: logger
        )
    }
    .flatMap(.concat) {
        sendFinalSPRequest(
            document: $0.0.value,
            idpRequestData: $0.1,
            log: logger
        )
    }
}
