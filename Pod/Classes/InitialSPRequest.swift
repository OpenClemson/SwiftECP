import Foundation
import XCGLogger

func buildInitialSPRequest(
    protectedURL: NSURL,
    log: XCGLogger?
) -> NSMutableURLRequest {
    // Create a request with the appropriate headers to trigger ECP on the SP.
    let request = NSMutableURLRequest(URL: protectedURL)
    request.setValue(
        "text/html; application/vnd.paos+xml",
        forHTTPHeaderField: "Accept"
    )
    request.setValue(
        "ver=\"urn:liberty:paos:2003-08\";\"urn:oasis:names:tc:SAML:2.0:profiles:SSO:ecp\"",
        forHTTPHeaderField: "PAOS"
    )
    request.timeoutInterval = 10
    log?.debug("Built initial SP request.")
    return request
}