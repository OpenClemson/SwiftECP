import Foundation
import Alamofire
import PromiseKit

extension Alamofire.Request {
	func response() -> Promise<(NSURLRequest, NSHTTPURLResponse, AnyObject)> {
		let (promise, fulfill, reject) = Promise<(NSURLRequest, NSHTTPURLResponse, AnyObject)>.defer()
		response(
			serializer: Request.responseDataSerializer(),
			completionHandler: { (request, response, data, error) in
				if let err = error { reject(err); return }
				if let rep = response, raw: AnyObject = data {
					fulfill(request, rep, raw); return
				}
				reject(AlamofirePromiseError.emptyResponse)
			}
		)
		return promise
	}
	
	func responseString(encoding: NSStringEncoding? = nil) -> Promise<(NSURLRequest, NSHTTPURLResponse, String)>  {
		let (promise, fulfill, reject) = Promise<(NSURLRequest, NSHTTPURLResponse, String)>.defer()
		response(
			serializer: Request.stringResponseSerializer(encoding: encoding),
			completionHandler: { (request, response, string, error) in
				if let err = error { reject(err); return }
				if let rep = response {
					if let body = string as? String {
						fulfill(request, rep, body); return
					}
					reject(AlamofirePromiseError.emptyBody); return
				}
				reject(AlamofirePromiseError.emptyResponse); return
			}
		)
		return promise
	}
}


struct AlamofirePromiseError {
	static let emptyResponse = NSError(
		domain: "Alamofire+PromiseKit",
		code: -500,
		userInfo: [
			NSLocalizedDescriptionKey: NSLocalizedString(
				"The request received no response.",
				comment: ""
			)
		]
	)
	static let emptyBody = NSError(
		domain: "Alamofire+PromiseKit",
		code: -500,
		userInfo: [
			NSLocalizedDescriptionKey: NSLocalizedString(
				"The request received a response with an empty body.",
				comment: ""
			)
		]
	)
}

