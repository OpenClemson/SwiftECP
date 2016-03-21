import Foundation
import AEXML
import Alamofire
import ReactiveCocoa
import XCGLogger

// swiftlint:disable:next todo
// TODO: refactor this function, the length does smell
// swiftlint:disable:next function_body_length
func buildIdpRequest(
    body: AEXMLDocument,
    username: String,
    password: String,
    log: XCGLogger?
) throws -> IdpRequestData {
    log?.debug("Initial SP SOAP response:")
    log?.debug(body.xmlString)

    // Remove the XML signature
    body.root["S:Body"]["samlp:AuthnRequest"]["ds:Signature"].removeFromParent()
    log?.debug("Removed the XML signature from the SP SOAP response.")

    // Store this so we can compare it against the AssertionConsumerServiceURL from the IdP
    let responseConsumerURLString = body.root["S:Header"]["paos:Request"]
        .attributes["responseConsumerURL"]

    guard let
        rcuString = responseConsumerURLString,
        responseConsumerURL = NSURL(string: rcuString)
    else {
        throw ECPError.ResponseConsumerURL
    }

    log?.debug("Found the ResponseConsumerURL in the SP SOAP response.")

    // Get the SP request's RelayState for later
    // This may or may not exist depending on the SP/IDP
    let relayState = body.root["S:Header"]["ecp:RelayState"].first

    if relayState != nil {
        log?.debug("SP SOAP response contains RelayState.")
    } else {
        log?.warning("No RelayState present in the SP SOAP response.")
    }

    // Get the IdP's URL
    // swiftlint:disable:next line_length
    let idpURLString = body.root["S:Body"]["samlp:AuthnRequest"]["samlp:Scoping"]["samlp:IDPList"]["samlp:IDPEntry"]
        .attributes["ProviderID"]

    guard let
        idp = idpURLString,
        idpURL = NSURL(string: idp),
        idpHost = idpURL.host,
        idpEcpURL = NSURL(string: "https://\(idpHost)/idp/profile/SAML2/SOAP/ECP")
    else {
        throw ECPError.IdpExtraction
    }

    log?.debug("Found IdP URL in the SP SOAP response.")
    // Make a new SOAP envelope with the SP's SOAP body only
    let body = body.root["S:Body"]
    let soapDocument = AEXMLDocument()
    let soapAttributes = [
        "xmlns:S": "http://schemas.xmlsoap.org/soap/envelope/"
    ]
    let envelope = soapDocument.addChild(
        name: "S:Envelope",
        attributes: soapAttributes
    )
    envelope.addChild(body)

    guard let soapString = envelope.xmlString.dataUsingEncoding(NSUTF8StringEncoding) else {
        throw ECPError.SoapGeneration
    }

    guard let authorizationHeader = basicAuthHeader(username, password: password) else {
        throw ECPError.MissingBasicAuth
    }

    log?.debug("Sending this SOAP to the IDP:")
    log?.debug(envelope.xmlString)

    let idpReq = NSMutableURLRequest(URL: idpEcpURL)
    idpReq.HTTPMethod = "POST"
    idpReq.HTTPBody = soapString
    idpReq.setValue(
        "application/vnd.paos+xml",
        forHTTPHeaderField: "Content-Type"
    )
    idpReq.setValue(
        authorizationHeader,
        forHTTPHeaderField: "Authorization"
    )
    log?.debug(authorizationHeader)
    idpReq.timeoutInterval = 10
    log?.debug("Built first IdP request.")

    return IdpRequestData(
        request: idpReq,
        responseConsumerURL: responseConsumerURL,
        relayState: relayState
    )
}

func sendIdpRequest(
    initialSpResponse: AEXMLDocument,
    username: String,
    password: String,
    log: XCGLogger?
) -> SignalProducer<(CheckedResponse<AEXMLDocument>, IdpRequestData), NSError> {
    return SignalProducer { observer, disposable in
        do {
            let idpRequestData = try buildIdpRequest(
                initialSpResponse,
                username: username,
                password: password,
                log: log
            )
            let req = Alamofire.request(idpRequestData.request)
            req.responseString().map { ($0, idpRequestData) }.start { event in
                switch event {
                case .Next(let value):

                    let stringResponse = value.0

                    guard case 200 ... 299 = stringResponse.response.statusCode else {
                        log?.debug(
                            "Received \(stringResponse.response.statusCode) response from IdP"
                        )
                        observer.sendFailed(ECPError.IdpRequestFailed.error)
                        break
                    }

                    guard let responseData = stringResponse.value
                        .dataUsingEncoding(NSUTF8StringEncoding)
                    else {
                        observer.sendFailed(ECPError.XMLSerialization.error)
                        break
                    }

                    guard let responseXML = try? AEXMLDocument(xmlData: responseData) else {
                        observer.sendFailed(ECPError.XMLSerialization.error)
                        break
                    }

                    let xmlResponse = CheckedResponse<AEXMLDocument>(
                        request: stringResponse.request,
                        response: stringResponse.response,
                        value: responseXML
                    )

                    observer.sendNext((xmlResponse, value.1))
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
