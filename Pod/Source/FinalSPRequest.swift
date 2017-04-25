import Alamofire
import Foundation
import AEXML
import ReactiveCocoa
import XCGLogger

// swiftlint:disable:next todo
// TODO: refactor this function, the length does smell
// swiftlint:disable:next function_body_length
func buildFinalSPRequest(
    body: AEXMLDocument,
    idpRequestData: IdpRequestData,
    log: XCGLogger?
) throws -> NSMutableURLRequest {
    log?.debug("IDP SOAP response:")
    log?.debug(body.xmlString)

    guard let
        acuString = body.root["soap11:Header"]["ecp:Response"]
            .attributes["AssertionConsumerServiceURL"],
        assertionConsumerServiceURL = NSURL(string: acuString)
    else {
        throw ECPError.AssertionConsumerServiceURL
    }

    log?.debug("Found AssertionConsumerServiceURL in IdP SOAP response.")

    // Make a new SOAP envelope with the following:
    //     - (optional) A SOAP Header containing the RelayState from the first SP response
    //     - The SOAP body of the IDP response
    let spSoapDocument = AEXMLDocument()

    // XML namespaces are just...lovely
    let spSoapAttributes = [
        "xmlns:S": "http://schemas.xmlsoap.org/soap/envelope/",
        "xmlns:soap11": "http://schemas.xmlsoap.org/soap/envelope/"
    ]
    let envelope = spSoapDocument.addChild(
        name: "S:Envelope",
        attributes: spSoapAttributes
    )

    // Bail out if these don't match
    guard
        idpRequestData.responseConsumerURL.URLString ==
        assertionConsumerServiceURL.URLString
    else {
        if let request = buildSoapFaultRequest(
            idpRequestData.responseConsumerURL,
            error: ECPError.Security.error
        ) {
            sendSpSoapFaultRequest(request, log: log)
        }
        throw ECPError.Security
    }

    if let relay = idpRequestData.relayState {
        let header = envelope.addChild(name: "S:Header")
        header.addChild(relay)
        log?.debug("Added RelayState to the SOAP header for the final SP request.")
    }

    let extractedBody = body.root["soap11:Body"]
    envelope.addChild(extractedBody)

    guard let bodyData = envelope.xmlString.dataUsingEncoding(NSUTF8StringEncoding) else {
        throw ECPError.SoapGeneration
    }

    log?.debug("Sending this SOAP to the SP:")
    log?.debug(envelope.xmlString)

    let spReq = NSMutableURLRequest(URL: assertionConsumerServiceURL)
    spReq.HTTPMethod = "POST"
    spReq.HTTPBody = bodyData
    spReq.setValue(
        "application/vnd.paos+xml",
        forHTTPHeaderField: "Content-Type"
    )
    spReq.timeoutInterval = 10

    log?.debug("Built final SP request.")
    return spReq
}

func sendFinalSPRequest(
    document: AEXMLDocument,
    idpRequestData: IdpRequestData,
    log: XCGLogger?
) -> SignalProducer<String, NSError> {
    return SignalProducer { observer, disposable in
        do {
            let request = try buildFinalSPRequest(
                document,
                idpRequestData: idpRequestData,
                log: log
            )

            let req = Alamofire.request(request)
            req.responseString(false).map { $0.value }.start { event in
                switch event {
                case .Next(let value):
                    observer.sendNext(value)
                    observer.sendCompleted()
                case .Failed(let error):
                    observer.sendFailed(error)
                default:
                    break
                }
            }
        } catch {
            observer.sendFailed(error as NSError)
        }
    }
}
