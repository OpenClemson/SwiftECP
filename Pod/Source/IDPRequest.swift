import AEXML_CU
import Alamofire
import AnyError
import XCGLogger
import Foundation
import ReactiveSwift

func basicAuthHeader(username: String, password: String) -> String? {
    let encodedUsernameAndPassword = ("\(username):\(password)")
        .data(using: .ascii)?
        .base64EncodedString()
    guard encodedUsernameAndPassword != nil else {
        return nil
    }
    return "Basic \(encodedUsernameAndPassword!)"
}

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
    log?.debug(body.xmlCompact)

    // Remove the XML signature
    // Disabled - not sure if this needs to be optional for some setups
    //    body.root["S:Body"]["samlp:AuthnRequest"]["ds:Signature"].removeFromParent()
    //    log?.debug("Removed the XML signature from the SP SOAP response.")

    // Store this so we can compare it against the AssertionConsumerServiceURL from the IdP
    let responseConsumerURLString = body.root["S:Header"]["paos:Request"]
        .attributes["responseConsumerURL"]

    guard let
        rcuString = responseConsumerURLString,
        let responseConsumerURL = URL(string: rcuString)
    else {
        throw ECPError.responseConsumerURL
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
        let idpURL = URL(string: idp),
        let idpHost = idpURL.host,
        let idpEcpURL = URL(string: "https://\(idpHost)/idp/profile/SAML2/SOAP/ECP")
    else {
        throw ECPError.idpExtraction
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

    let soapString = envelope.xmlString(trimWhiteSpace: false, format: false)

    guard let soapData = soapString.data(using: String.Encoding.utf8) else {
        throw ECPError.soapGeneration
    }

    guard let authorizationHeader = basicAuthHeader(username: username, password: password) else {
        throw ECPError.missingBasicAuth
    }

    log?.debug("Sending this SOAP to the IDP:")
    log?.debug(soapString)

    var idpReq = URLRequest(url: idpEcpURL)
    idpReq.httpMethod = "POST"
    idpReq.httpBody = soapData

    idpReq.setValue(
        "text/xml; charset=\"UTF-8\"",
        forHTTPHeaderField: "Content-Type"
    )

    idpReq.setValue(
        "identity",
        forHTTPHeaderField: "Accept-Encoding"
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
) -> SignalProducer<(CheckedResponse<AEXMLDocument>, IdpRequestData), AnyError> {
    return SignalProducer { observer, _ in
        do {
            let idpRequestData = try buildIdpRequest(
                body: initialSpResponse,
                username: username,
                password: password,
                log: log
            )

            let req = Alamofire.request(idpRequestData.request)

            req.responseString().map { ($0, idpRequestData) }.start { event in
                switch event {
                case let .value(value):
                    let stringResponse = value.0

                    guard case 200 ... 299 = stringResponse.response.statusCode else {
                        log?.debug(
                            "Received \(stringResponse.response.statusCode) response from IdP"
                        )
                        observer.send(error: ECPError.idpRequestFailed.asAnyError())
                        break
                    }

                    guard let responseData = stringResponse.value
                        .data(using: String.Encoding.utf8)
                    else {
                        observer.send(error: ECPError.xmlSerialization.asAnyError())
                        break
                    }

                    guard let responseXML = try? AEXMLDocument(xml: responseData) else {
                        observer.send(error: ECPError.xmlSerialization.asAnyError())
                        break
                    }

                    let xmlResponse = CheckedResponse<AEXMLDocument>(
                        request: stringResponse.request,
                        response: stringResponse.response,
                        value: responseXML
                    )

                    observer.send(value: (xmlResponse, value.1))
                    observer.sendCompleted()
                case .failed(let error):
                    observer.send(error: error)
                default:
                    break
                }
            }
        } catch {
            observer.send(error: AnyError(cause: error))
        }
    }
}
