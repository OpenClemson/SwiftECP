import Foundation

public enum ECPError: ErrorType {
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
    case IdpRequestFailed
    case XMLSerialization

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
        case .IdpRequestFailed:
            return 210
        case .XMLSerialization:
            return 211
        }
    }

    var userMessage: String {
        switch self {
        case .EmptyBody:
            return "The password you entered is incorrect. Please try again."
        case .IdpRequestFailed:
            return "The password you entered is incorrect. Please try again."
        default:
            // swiftlint:disable:next line_length
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
        case .IdpRequestFailed:
            return "IdP request failed. The given password is likely incorrect."
        case .XMLSerialization:
            return "Unable to serialize response to XML."
        }
    }

    var error: NSError {
        return NSError(domain: domain, code: errorCode, userInfo: [
            NSLocalizedDescriptionKey: userMessage,
            NSLocalizedFailureReasonErrorKey: description
        ])
    }
}
