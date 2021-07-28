import Foundation

public final class URLSessionProxyDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    private weak var actualDelegate: URLSessionDelegate?
    private weak var taskDelegate: URLSessionTaskDelegate?
    private let interceptedSelectors: Set<Selector>

    /// - parameter delegate: The "real" session delegate.
    public init(delegate: URLSessionDelegate) {
        self.actualDelegate = delegate
        self.taskDelegate = delegate as? URLSessionTaskDelegate
        self.interceptedSelectors = [
            #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)),
            #selector(URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)),
            #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:)),
            #selector(URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:))
        ]
    }

    // MARK: URLSessionTaskDelegate

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        taskDelegate?.urlSession?(session, task: task, didCompleteWithError: error)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        taskDelegate?.urlSession?(session, task: task, didFinishCollecting: metrics)
    }

    // MARK: URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if actualDelegate?.responds(to: #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:))) ?? false {
            (actualDelegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
        } else {
            completionHandler(.allow)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        sharedPresentableStoreDebugger?.networkLogger.logTask(dataTask, data: data)
        (actualDelegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: data)
    }

    // MARK: Proxy

    public override func responds(to aSelector: Selector!) -> Bool {
        if interceptedSelectors.contains(aSelector) {
            return true
        }
        return (actualDelegate?.responds(to: aSelector) ?? false) || super.responds(to: aSelector)
    }

    public override func forwardingTarget(for selector: Selector!) -> Any? {
        interceptedSelectors.contains(selector) ? nil : actualDelegate
    }
}

private extension URLSession {
    @objc class func proxy_init(configuration: URLSessionConfiguration, delegate: URLSessionDelegate, delegateQueue: OperationQueue?) -> URLSession {
        let delegate = URLSessionProxyDelegate(delegate: delegate)
        return self.proxy_init(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }
}

public extension URLSessionProxyDelegate {
    static func exhangeDelegateImplementation() -> Void {
        if let lhs = class_getClassMethod(URLSession.self, #selector(URLSession.init(configuration:delegate:delegateQueue:))),
           let rhs = class_getClassMethod(URLSession.self, #selector(URLSession.proxy_init(configuration:delegate:delegateQueue:))) {
            method_exchangeImplementations(lhs, rhs)
        }
    }
}
