import Quick
import Nimble
@testable import SwiftECP

class SwiftECPSpec: QuickSpec {
    override func spec() {
        describe("Initial SP request") {
            it("inits with the correct headers and timeout") {
                let request = buildInitialSPRequest(
                    NSURL(string: "https://app.university.edu")!, log: nil
                )
                expect(request.URLString).to(equal("https://app.university.edu"))
                expect(request.valueForHTTPHeaderField("Accept")).to(equal(
                    "text/html; application/vnd.paos+xml"
                ))
                expect(request.valueForHTTPHeaderField("PAOS")).to(equal(
                    // swiftlint:disable:next line_length
                    "ver=\"urn:liberty:paos:2003-08\";\"urn:oasis:names:tc:SAML:2.0:profiles:SSO:ecp\""
                ))
                expect(request.timeoutInterval).to(equal(10))
            }
        }
    }
}
