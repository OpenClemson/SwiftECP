import UIKit
import SwiftECP

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
		
		ECP(
			username: "nobody",
			password: "nothing",
			protectedURL: NSURL(
				string: "https://my.dev.clemson.edu/srv/broker/redirect.php"
			)!
		).login().then { cookie in
			println(cookie)
		}.catch { error in
			println(error.localizedDescription)
			println(error.localizedFailureReason)
		}
    }
}

