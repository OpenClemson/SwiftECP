import Quick
import Nimble
@testable import SwiftECP

class SwiftECPSpec: QuickSpec {
    override func spec() {
        describe("Initial SP request") {
            it("inits with the correct headers and timeout") {
                let request = buildInitialSPRequest(
                    protectedURL: URL(string: "https://app.university.edu")!, log: nil
                )
                expect(request.url?.absoluteString).to(equal("https://app.university.edu"))
                expect(request.value(forHTTPHeaderField: "Accept")).to(equal(
                    "text/html; application/vnd.paos+xml"
                ))
                expect(request.value(forHTTPHeaderField: "PAOS")).to(equal(
                    "ver=\"urn:liberty:paos:2003-08\";\"urn:oasis:names:tc:SAML:2.0:profiles:SSO:ecp\""
                ))
                expect(request.timeoutInterval).to(equal(10))
            }
        }
    }
}
