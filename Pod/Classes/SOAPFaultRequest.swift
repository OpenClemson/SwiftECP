import Foundation
import Alamofire
import AEXML
import XCGLogger

// Something the spec wants but we don't need. Fire and forget.
func sendSpSoapFaultRequest(
    request: NSMutableURLRequest,
    log: XCGLogger?
) {
    let request = Alamofire.request(request)
    request.responseString { response in
        if let value = response.result.value {
            log?.debug(value)
        } else if let error = response.result.error {
            log?.warning(error.localizedDescription)
        }
    }
}

func buildSoapFaultBody(error: NSError) -> NSData? {
    let soapDocument = AEXMLDocument()
    let soapAttribute = [
        "xmlns:SOAP-ENV": "http://schemas.xmlsoap.org/soap/envelope/"
    ]
    let envelope = soapDocument.addChild(
        name: "SOAP-ENV:Envelope",
        attributes: soapAttribute
    )
    let body = envelope.addChild(name: "SOAP-ENV:Body")
    let fault = body.addChild(name: "SOAP-ENV:Fault")
    fault.addChild(name: "faultcode", value: String(error.code))
    fault.addChild(name: "faultstring", value: error.localizedDescription)
    return soapDocument.xmlString.dataUsingEncoding(NSUTF8StringEncoding)
}

func buildSoapFaultRequest(URL: NSURL, error: NSError) -> NSMutableURLRequest? {
    if let body = buildSoapFaultBody(error) {
        let request = NSMutableURLRequest(URL: URL)
        request.HTTPMethod = "POST"
        request.HTTPBody = body
        request.setValue(
            "application/vnd.paos+xml",
            forHTTPHeaderField: "Content-Type"
        )
        request.timeoutInterval = 10

        return request
    }
    return nil
}
