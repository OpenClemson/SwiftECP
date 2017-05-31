import AEXML_CU
import Alamofire
import AnyError
import Foundation
import ReactiveSwift

public struct CheckedResponse<T> {
    let request: URLRequest
    let response: HTTPURLResponse
    let value: T
}

extension DataRequest {
    public static func xmlResponseSerializer() -> DataResponseSerializer<AEXMLDocument> {
        return DataResponseSerializer { _, resp, data, error in
            guard error == nil else { return .failure(AlamofireRACError.network(error: error)) }

            let result = Request.serializeResponseData(response: resp, data: data, error: nil)

            guard case let .success(validData) = result else {
                return .failure(AlamofireRACError.dataSerialization(error: error))
            }

            do {
                let document = try AEXMLDocument(xml: validData)
                return .success(document)
            } catch {
                return .failure(AlamofireRACError.xmlSerialization)
            }
        }
    }

    public static func emptyAllowedStringResponseSerializer() -> DataResponseSerializer<String> {
        return DataResponseSerializer { _, resp, data, error in
            guard error == nil else { return .failure(AlamofireRACError.network(error: error)) }

            let result = Request.serializeResponseData(response: resp, data: data, error: nil)

            guard case let .success(validData) = result else {
                return .failure(AlamofireRACError.dataSerialization(error: error))
            }

            guard let string = String(data: validData, encoding: String.Encoding.utf8) else {
                return .success("")
            }

            return .success(string)
        }
    }

    @discardableResult
    public func responseXML(
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DataResponse<AEXMLDocument>) -> Void)
        -> Self {
        return response(
            queue: queue,
            responseSerializer: DataRequest.xmlResponseSerializer(),
            completionHandler: completionHandler
        )
    }

    @discardableResult
    public func responseStringEmptyAllowed(
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DataResponse<String>) -> Void
        ) -> Self {
        return response(
            queue: queue,
            responseSerializer: DataRequest.emptyAllowedStringResponseSerializer(),
            completionHandler: completionHandler
        )
    }

    public func responseXML() -> SignalProducer<CheckedResponse<AEXMLDocument>, AnyError> {
        return SignalProducer { observer, _ in
            self.responseXML { response in
                if let error = response.result.error {
                    return observer.send(error: AnyError(cause: error))
                }

                guard let document = response.result.value else {
                    return observer.send(error: AlamofireRACError.xmlSerialization.asAnyError())
                }

                guard let request = response.request, let response = response.response else {
                    return observer.send(error: AlamofireRACError.incompleteResponse.asAnyError())
                }

                observer.send(
                    value: CheckedResponse<AEXMLDocument>(
                        request: request, response: response, value: document
                    )
                )
                observer.sendCompleted()
            }
        }
    }

    public func responseString(
        errorOnNil: Bool = true
        ) -> SignalProducer<CheckedResponse<String>, AnyError> {
        return SignalProducer { observer, _ in
            self.responseStringEmptyAllowed { response in
                if let error = response.result.error {
                    return observer.send(error: AnyError(cause: error))
                }

                if errorOnNil && response.result.value?.characters.count == 0 {
                    return observer.send(error: AlamofireRACError.incompleteResponse.asAnyError())
                }

                guard let req = response.request, let resp = response.response else {
                    return observer.send(error: AlamofireRACError.incompleteResponse.asAnyError())
                }

                observer.send(
                    value: CheckedResponse<String>(
                        request: req, response: resp, value: response.result.value ?? ""
                    )
                )
                observer.sendCompleted()
            }
        }
    }
}

public enum AlamofireRACError: Error, AnyErrorConverter {
    case network(error: Error?)
    case dataSerialization(error: Error?)
    case xmlSerialization
    case incompleteResponse
    case unknownError

    public var description: String {
        switch self {
        case .network(let error):
            return "There was a network issue: \(String(describing: error))."
        case .dataSerialization(let error):
            return "Could not serialize data: \(String(describing: error))."
        case .xmlSerialization:
            return "Could not serialize XML."
        case .incompleteResponse:
            return "Incomplete response."
        default:
            return "There was an unknown error."
        }
    }
}
