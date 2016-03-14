import Foundation
import AEXML
import Alamofire
//import BrightFutures
import ReactiveCocoa

public struct CheckedResponse<T> {
    let request: NSURLRequest
    let response: NSHTTPURLResponse
    let value: T
}

extension Alamofire.Request {
    public static func XMLResponseSerializer() -> ResponseSerializer<AEXMLDocument, NSError> {
        return ResponseSerializer { _, resp, data, error in
            guard error == nil else { return .Failure(error!) }

            guard let validData = data where validData.length > 0 else {
                let failureReason = "Could not serialize data. Input data was nil or zero length."
                let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
                return .Failure(error)
            }

            do {
                let document = try AEXMLDocument(xmlData: validData)
                return .Success(document)
            } catch {
                return .Failure(error as NSError)
            }
        }
    }

    public static func emptyAllowedStringResponseSerializer() -> ResponseSerializer<String, NSError> {
        return ResponseSerializer { _, resp, data, error in
            guard error == nil else { return .Failure(error!) }

            guard let
                validData = data,
                string = String(data: validData, encoding: NSUTF8StringEncoding)
            else {
                return .Success("")
            }

            return .Success(string)
        }
    }

    public func responseXML(completionHandler: Response<AEXMLDocument, NSError> -> Void) -> Self {
        return response(responseSerializer: Request.XMLResponseSerializer(), completionHandler: completionHandler)
    }

    public func responseStringEmptyAllowed(completionHandler: Response<String, NSError> -> Void) -> Self {
        return response(responseSerializer: Request.emptyAllowedStringResponseSerializer(), completionHandler: completionHandler)
    }

    public func responseXML() -> SignalProducer<CheckedResponse<AEXMLDocument>, NSError> {
        return SignalProducer { observer, disposable in
            self.responseXML { response in
                if let error = response.result.error {
                    return observer.sendFailed(error)
                }

                guard let document = response.result.value else {
                    return observer.sendFailed(AlamofireRACError.XMLSerialization as NSError)
                }

                guard let request = response.request, response = response.response else {
                    return observer.sendFailed(AlamofireRACError.IncompleteResponse as NSError)
                }

                observer.sendNext(
                    CheckedResponse<AEXMLDocument>(
                        request: request, response: response, value: document
                    )
                )
                observer.sendCompleted()
            }
        }
    }

    public func responseString(errorOnNil: Bool = true) -> SignalProducer<CheckedResponse<String>, NSError> {
        return SignalProducer { observer, disposable in
            self.responseStringEmptyAllowed { response in
                if let error = response.result.error {
                    return observer.sendFailed(error)
                }

                if errorOnNil && response.result.value?.characters.count == 0 {
                    return observer.sendFailed(AlamofireRACError.IncompleteResponse as NSError)
                }

                guard let req = response.request, resp = response.response else {
                    return observer.sendFailed(AlamofireRACError.IncompleteResponse as NSError)
                }

                observer.sendNext(
                    CheckedResponse<String>(
                        request: req, response: resp, value: response.result.value ?? ""
                    )
                )
                observer.sendCompleted()
            }
        }
    }
}

enum AlamofireRACError: ErrorType {
    case XMLSerialization
    case IncompleteResponse
}
