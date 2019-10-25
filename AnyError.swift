// https://github.com/NickAger/AnyError
import Foundation

/**
 Type erasing type `ErrorType`
 
 See also:
 - [Type erasure with AnyError](http://nickager.com/blog/2016/03/07/AnyError)
 */
public struct AnyError : Error {
    public let cause:Error
    
    public init(cause:Error) {
        self.cause = cause
    }
}

/**
 Protocol extension designed as a mix-in to add `asAnyError` to any `ErrorType`
 
 See also:
 - [Type erasure with AnyError](http://nickager.com/blog/2016/03/07/AnyError)
 */

public protocol AnyErrorConverter : Error {
    func asAnyError() -> AnyError

}

public extension AnyErrorConverter {
    func asAnyError() -> AnyError {
        return AnyError(cause: self)
    }
}
