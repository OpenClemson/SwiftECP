import Foundation
import Alamofire
import AEXML
import PromiseKit
import XCGLogger

public struct ECP {
	public let username: String
	public let password: String
	var basicAuth: String? {
		get {
			return ("\(username):\(password)" as NSString)
				.dataUsingEncoding(NSASCIIStringEncoding)?
				.base64EncodedStringWithOptions(nil)
		}
	}
	public let protectedURL: NSURL
	
	let log = XCGLogger.defaultInstance()
	
	public init(username: String, password: String, protectedURL: NSURL, logLevel: XCGLogger.LogLevel) {
		self.username = username
		self.password = password
		self.protectedURL = protectedURL
		log.setup(
			logLevel: logLevel,
			showLogLevel: true,
			showFileNames: true,
			showLineNumbers: true,
			writeToFile: nil,
			fileLogLevel: nil
		)
	}
	
	struct IdpRequestData {
		let request: NSMutableURLRequest
		let responseConsumerURL: NSURL
		let relayState: AEXMLElement?
	}
	
	struct IdpResponseData {
		let requestData: IdpRequestData
		let response: NSHTTPURLResponse
		let body: String
	}
	
	public func login() -> Promise<(NSURLRequest, NSHTTPURLResponse, String)> {
		// TODO: Directly chain the Alamofire requests after compiler
		// bug gets fixed: https://github.com/mxcl/PromiseKit/issues/198
		let request = Alamofire.request(self.buildInitialRequest())
		return request.responseString()
		.then { req, resp, string -> Promise<IdpRequestData> in
			self.log.debug("(1/3) Initial SP request complete. Status: \(resp.statusCode).")
			return self.buildIdpRequest(string)
		}.then { idpRequestData -> Promise<(NSURLRequest, NSHTTPURLResponse, String, IdpRequestData)> in
			return Promise { fulfill, reject in
				let request = Alamofire.request(idpRequestData.request)
				request.responseString().then {
					fulfill($0, $1, $2, idpRequestData)
				}
			}
		}.then { req, resp, string, idpRequestData -> Promise<NSMutableURLRequest> in
			self.log.debug("(2/3) IdP request complete. Status: \(resp.statusCode)")
			let idpResponseData = IdpResponseData(
				requestData: idpRequestData,
				response: resp,
				body: string
			)
			return self.buildSpRequest(idpResponseData)
		}.then { spRequest -> Promise<(NSURLRequest, NSHTTPURLResponse, String)> in
			self.log.debug("(3/3) Building final SP request.")
			let request = Alamofire.request(spRequest)
 			return request.responseString()
		}
	}

	func buildInitialRequest() -> NSMutableURLRequest {
		// Create a request with the appropriate headers to trigger ECP on the SP.
		let request = NSMutableURLRequest(URL: self.protectedURL)
		request.setValue(
			"text/html; application/vnd.paos+xml",
			forHTTPHeaderField: "Accept"
		)
		request.setValue(
			"ver=\"urn:liberty:paos:2003-08\";\"urn:oasis:names:tc:SAML:2.0:profiles:SSO:ecp\"",
			forHTTPHeaderField: "PAOS"
		)
		request.timeoutInterval = 10
		self.log.debug("Built initial SP request.")
		return request
	}

	func buildIdpRequest(body: String) -> Promise<IdpRequestData> {
		return Promise { fulfill, reject in
			var error: NSError?
			if let
				xmlData = body.dataUsingEncoding(NSUTF8StringEncoding),
				xml = AEXMLDocument(xmlData: xmlData, error: &error)
			{
				// Bust out if there's an XML parse error
				if let err = error { reject(err); return }
				
				// Remove the XML signature
				xml.root["S:Body"]["samlp:AuthnRequest"]["ds:Signature"].removeFromParent()
				self.log.debug("Removed the XML signature from the SP SOAP response.")
				
				// Store this so we can compare it against the AssertionConsumerServiceURL from the IdP
				let responseConsumerURLString = xml.root["S:Header"]["paos:Request"]
					.attributes["responseConsumerURL"] as? String
				
				if let
					rcuString = responseConsumerURLString,
					responseConsumerURL = NSURL(string: rcuString)
				{
					self.log.debug("Found the ResponseConsumerURL in the SP SOAP response.")
					
					// Get the SP request's RelayState for later
					// This may or may not exist depending on the SP/IDP
					let relayState = xml.root["S:Header"]["ecp:RelayState"].first
					
					if relayState != nil {
						self.log.debug("SP SOAP response contains RelayState.")
					} else {
						self.log.warning("No RelayState present in the SP SOAP response.")
					}
					
					// Get the IdP's URL
					let idpURLString = xml.root["S:Body"]["samlp:AuthnRequest"]["samlp:Scoping"]["samlp:IDPList"]["samlp:IDPEntry"]
						.attributes["ProviderID"] as? String
					if let
						idp = idpURLString,
						idpURL = NSURL(string: idp),
						idpHost = idpURL.host,
						idpEcpURL = NSURL(string: "https://\(idpHost)/idp/profile/SAML2/SOAP/ECP")
					{
						self.log.debug("Found IdP URL in the SP SOAP response.")
						// Make a new SOAP envelope with the SP's SOAP body only
						let body = xml.root["S:Body"]
						let soapDocument = AEXMLDocument()
						let soapAttributes = [
							"xmlns:S": "http://schemas.xmlsoap.org/soap/envelope/"
						]
						let envelope = soapDocument.addChild(
							name: "S:Envelope",
							attributes: soapAttributes
						)
						envelope.addChild(body)

						if let soapString = envelope.xmlString.dataUsingEncoding(NSUTF8StringEncoding) {
							if let basicAuth = self.basicAuth {
								let idpReq = NSMutableURLRequest(URL: idpEcpURL)
								idpReq.HTTPMethod = "POST"
								idpReq.HTTPBody = soapString
								idpReq.setValue(
									"application/vnd.paos+xml",
									forHTTPHeaderField: "Content-Type"
								)
								idpReq.setValue(
									"Basic " + basicAuth,
									forHTTPHeaderField: "Authorization"
								)
								idpReq.timeoutInterval = 10
								self.log.debug("Built first IdP request.")
								
								return fulfill(IdpRequestData(
									request: idpReq,
									responseConsumerURL: responseConsumerURL,
									relayState: relayState
								))
							}
							return reject(Error.MissingBasicAuth.error)
						}
						return reject(Error.SoapGeneration.error)
					}
					return reject(Error.IdpExtraction.error)
				}
				return reject(Error.ResponseConsumerURL.error)
			}
			return reject(Error.WTF.error) // is this even reachable?
		}
	}
	
	func buildSpRequest(idpResponseData: IdpResponseData) -> Promise<NSMutableURLRequest> {
		return Promise { fulfill, reject in
			var xmlError: NSError?
			if let
				xmlData = idpResponseData.body.dataUsingEncoding(NSUTF8StringEncoding),
				xml = AEXMLDocument(xmlData: xmlData, error: &xmlError)
			{
				if let err = xmlError { reject(err); return }
				
				if let
					acuString = xml.root["soap11:Header"]["ecp:Response"]
						.attributes["AssertionConsumerServiceURL"] as? String,
					assertionConsumerServiceURL = NSURL(string: acuString)
				{
					self.log.debug("Found AssertionConsumerServiceURL in IdP SOAP response.")
					
					// Make a new SOAP envelope with the following:
					//     - (optional) A SOAP Header containing the RelayState from the first SP response
					//     - The SOAP body of the IDP response
					let spSoapDocument = AEXMLDocument()
					
					// XML namespaces are just...lovely
					let spSoapAttributes = [
						"xmlns:S": "http://schemas.xmlsoap.org/soap/envelope/",
						"xmlns:soap11": "http://schemas.xmlsoap.org/soap/envelope/"
					]
					let envelope = spSoapDocument.addChild(
						name: "S:Envelope",
						attributes: spSoapAttributes
					)
					
					if let relay = idpResponseData.requestData.relayState {
						let header = envelope.addChild(name: "S:Header")
						let relayElement = header.addChild(relay)
						self.log.debug("Added RelayState to the SOAP header for the final SP request.")
					}
					
					let body = xml.root["soap11:Body"]
					envelope.addChild(body)
					
					if let bodyData = envelope.xmlString.dataUsingEncoding(NSUTF8StringEncoding) {
						// Bail out if these don't match
						if idpResponseData.requestData.responseConsumerURL.URLString != assertionConsumerServiceURL.URLString {
							if let request = self.buildSoapFaultRequest(
								idpResponseData.requestData.responseConsumerURL,
								error: Error.Security.error
							) {
								// We don't care about the results of the SOAP
								// fault request, the spec just requires us to send it
								self.sendSpSoapFaultRequest(request)
							}
							reject(Error.Security.error); return
						}
						
						if let basicAuth = self.basicAuth {
							let spReq = NSMutableURLRequest(URL: assertionConsumerServiceURL)
							spReq.HTTPMethod = "POST"
							spReq.HTTPBody = bodyData
							spReq.setValue(
								"application/vnd.paos+xml",
								forHTTPHeaderField: "Content-Type"
							)
							spReq.setValue(
								"Basic " + basicAuth,
								forHTTPHeaderField: "Authorization"
							)
							spReq.timeoutInterval = 10

							self.log.debug("Built final SP request.")
							return fulfill(spReq)
						}
						return reject(Error.MissingBasicAuth.error)
					}
					return reject(Error.SoapGeneration.error)
				}
				return reject(Error.AssertionConsumerServiceURL.error)
			}
			return reject(Error.EmptyBody.error)
		}
	}
	
	// Something the spec wants but we don't need. Fire and forget.
	func sendSpSoapFaultRequest(request: NSMutableURLRequest) {
		Alamofire.Manager.sharedInstance.request(request)
			.responseString { (request, response, string, error) in
				if let err = error {
					self.log.warning("Error sending SOAP fault:")
					self.log.warning(err.localizedDescription)
				}
				if let body = string {
					self.log.debug(body)
				} else {
					self.log.warning("Empty response from SOAP fault request.")
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
		let faultCode = fault.addChild(name: "faultcode", value: String(error.code))
		let faultString = fault.addChild(name: "faultstring", value: error.localizedDescription)
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
	
	enum Error: Printable {
		case Extraction
		case EmptyBody
		case SoapGeneration
		case IdpExtraction
		case RelayState
		case ResponseConsumerURL
		case AssertionConsumerServiceURL
		case Security
		case MissingBasicAuth
		case WTF
		
		private var domain: String {
			return "edu.clemson.swiftecp"
		}
		
		private var errorCode: Int {
			switch self {
			case .Extraction:
				return 200
			case .EmptyBody:
				return 201
			case .SoapGeneration:
				return 202
			case .IdpExtraction:
				return 203
			case .RelayState:
				return 204
			case .ResponseConsumerURL:
				return 205
			case .AssertionConsumerServiceURL:
				return 206
			case .Security:
				return 207
			case .MissingBasicAuth:
				return 208
			case .WTF:
				return 209
			}
		}
		
		var userMessage: String {
			switch self {
			case .EmptyBody:
				return "The password you entered is incorrect. Please try again."
			default:
				return "An unknown error occurred. Please let us know how you arrived at this error and we will fix the problem as soon as possible."
			}
		}
		
		var description: String {
			switch self {
			case .Extraction:
				return "Could not extract the necessary info from the XML response."
			case .EmptyBody:
				return "Empty body. The given password is likely incorrect."
			case .SoapGeneration:
				return "Could not generate a valid SOAP request body from the response's SOAP body."
			case .IdpExtraction:
				return "Could not extract the IDP endpoint from the SOAP body."
			case .RelayState:
				return "Could not extract the RelayState from the SOAP body."
			case .ResponseConsumerURL:
				return "Could not extract the ResponseConsumerURL from the SOAP body."
			case .AssertionConsumerServiceURL:
				return "Could not extract the AssertionConsumerServiceURL from the SOAP body."
			case .Security:
				return "ResponseConsumerURL did not match AssertionConsumerServiceURL."
			case .MissingBasicAuth:
				return "Could not generate basic auth from the given username and password."
			case .WTF:
				return "Unknown error. Please contact the library developer."
			}
		}
		
		var error: NSError {
			return NSError(domain: domain, code: errorCode, userInfo: [
				NSLocalizedDescriptionKey: userMessage,
				NSLocalizedFailureReasonErrorKey: description
			])
		}
	}
}