import UIKit
import SwiftECP
import XCGLogger

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let username = "YOUR_USERNAME"
        let password = "YOUR_PASSWORD"
        let protectedURL = URL(
            string: "https://app.university.edu"
        )!
        let logger = XCGLogger()
        logger.setup(level: .debug)

        ECPLogin(
            protectedURL: protectedURL,
            username: username,
            password: password,
            logger: logger
        ).start { event in
            switch event {

            case let .value(body):
                // If the request was successful, the protected resource will
                // be available in 'body'. Make sure to implement a mechanism to
                // detect authorization timeouts.
                print("Response body: \(body)")

                // The Shibboleth auth cookie is now stored in the sharedHTTPCookieStorage.
                // Attach this cookie to subsequent requests to protected resources.
                // You can access the cookie with the following code:
                if let cookies = HTTPCookieStorage.shared.cookies {
                    let shibCookie = cookies.filter { (cookie: HTTPCookie) in
                        cookie.name.range(of: "shibsession") != nil
                    }[0]
                    print(shibCookie)
                }

            case let .failed(error):
                // This is an AnyError that wraps the error thrown.
                // This can help diagnose problems with your SP, your IdP, or even this library :)

                switch error.cause {
                case let ecpError as ECPError:
                    print("We got an ECP Error!")
                    // User-friendly error message
                    print(ecpError.userMessage)

                    // Technical/debug error message
                    print(ecpError.description)
                case let alamofireRACError as AlamofireRACError:
                    print("We got a networking error!")
                    print(alamofireRACError.description)
                default:
                    print("Unknown error!")
                    print(error)
                }

            default:
                break
            }
        }
    }
}
