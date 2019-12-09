import Foundation

public enum ECPError: Error, AnyErrorConverter {
    case extraction
    case emptyBody
    case soapGeneration
    case idpExtraction
    case relayState
    case responseConsumerURL
    case assertionConsumerServiceURL
    case security
    case missingBasicAuth
    case wtf
    case idpRequestFailed
    case xmlSerialization

    public var errorCode: Int {
        switch self {
        case .extraction:
            return 200
        case .emptyBody:
            return 201
        case .soapGeneration:
            return 202
        case .idpExtraction:
            return 203
        case .relayState:
            return 204
        case .responseConsumerURL:
            return 205
        case .assertionConsumerServiceURL:
            return 206
        case .security:
            return 207
        case .missingBasicAuth:
            return 208
        case .wtf:
            return 209
        case .idpRequestFailed:
            return 210
        case .xmlSerialization:
            return 211
        }
    }

    public var userMessage: String {
        switch self {
        case .emptyBody:
            return "The password you entered is incorrect. Please try again."
        case .idpRequestFailed:
            return "The password you entered is incorrect. Please try again."
        default:
            // swiftlint:disable:next line_length
            return "An unknown error occurred. Please let us know how you arrived at this error and we will fix the problem as soon as possible."
        }
    }

    public var description: String {
        switch self {
        case .extraction:
            return "Could not extract the necessary info from the XML response."
        case .emptyBody:
            return "Empty body. The given password is likely incorrect."
        case .soapGeneration:
            return "Could not generate a valid SOAP request body from the response's SOAP body."
        case .idpExtraction:
            return "Could not extract the IDP endpoint from the SOAP body."
        case .relayState:
            return "Could not extract the RelayState from the SOAP body."
        case .responseConsumerURL:
            return "Could not extract the ResponseConsumerURL from the SOAP body."
        case .assertionConsumerServiceURL:
            return "Could not extract the AssertionConsumerServiceURL from the SOAP body."
        case .security:
            return "ResponseConsumerURL did not match AssertionConsumerServiceURL."
        case .missingBasicAuth:
            return "Could not generate basic auth from the given username and password."
        case .wtf:
            return "Unknown error. Please contact the library developer."
        case .idpRequestFailed:
            return "IdP request failed. The given password is likely incorrect."
        case .xmlSerialization:
            return "Unable to serialize response to XML."
        }
    }
}
