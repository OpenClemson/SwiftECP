import UIKit
import SwiftECP

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
		
		ECP(
			username: "nobody",
			password: "nothing",
			protectedURL: NSURL(
				string: "https://app.university.edu/protected"
			)!,
			logLevel: .Debug
		).login().then { request, response, body -> Void in
			println(body)
			
			if let cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage().cookies as? [NSHTTPCookie] {
				let shibCookie = cookies.filter { (cookie: NSHTTPCookie) in
					cookie.name.rangeOfString("shibsession") != nil
				}[0]
				println(shibCookie)
			}
		}.catch { error in
			println(error.localizedDescription)
			println(error.localizedFailureReason)
		}
    }
}

