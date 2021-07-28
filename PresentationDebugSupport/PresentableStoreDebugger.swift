//
//  PresentableStoreDebugger.swift
//  Presentation
//
//  Created by Sam Pettersson on 2021-07-18.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import Swifter
import Flow
import Runtime
import Presentation

struct StoreDebuggerRepresentationActionInput: Codable {
    let type: String
    let name: String
    let inputs: [StoreDebuggerRepresentationActionInput]
}

struct StoreDebuggerRepresentationAction: Codable {
    let name: String
    let inputs: [StoreDebuggerRepresentationActionInput]
}

struct StoreDebuggerRepresentation: Codable {
    let name: String
    let actions: [StoreDebuggerRepresentationAction]
}

struct StoreDebuggerContainer: Codable {
    var stores: [StoreDebuggerRepresentation] = []
}

struct StateWebsocketResponse: Codable {
    var name: String
    var state: String
}

var sharedPresentableStoreDebugger: PresentableStoreDebugger? = nil

public class PresentableStoreDebugger: Debugger {
    let bag = DisposeBag()
    
    public init() {}
    
    var websocketSessions: [WebSocketSession] = []
    var decodeAndSenders: [String: (Data) -> Void] = [:]
    var container = StoreDebuggerContainer()
    
    var actionHistory: [String: [Any]] = [:]
    
    let websocketConnect = Callbacker<Void>()
    
    public func registerStore<S: Store>(_ store: S) {
        let actionInfo = try! typeInfo(of: S.Action.self)
        
        decodeAndSenders[String(describing: store)] = { data in
            let action = try? JSONDecoder().decode(S.Action.self, from: data)
            
            if let action = action {
                store.send(action)
            }
        }
        
        container.stores.append(StoreDebuggerRepresentation(
            name: String(describing: store),
            actions: actionInfo.cases.map { action in
                guard let payloadType = action.payloadType else {
                    return StoreDebuggerRepresentationAction(
                        name: action.name,
                        inputs: []
                    )
                }
                
                let payloadTypeInfo = try! typeInfo(of: payloadType)
                
                func mapPropertiesToInput(_ properties: [Runtime.PropertyInfo]) -> [StoreDebuggerRepresentationActionInput] {
                    properties.compactMap { property in
                        if property.type as? String.Type != nil {
                            return StoreDebuggerRepresentationActionInput(
                                type: "String",
                                name: property.name,
                                inputs: []
                            )
                        }
                        
                        guard let propertyTypeInfo = try? typeInfo(of: property.type) else {
                            return nil
                        }
                        
                        return StoreDebuggerRepresentationActionInput(
                            type: propertyTypeInfo.name,
                            name: property.name,
                            inputs: mapPropertiesToInput(propertyTypeInfo.properties)
                        )
                    }
                }
            
                return StoreDebuggerRepresentationAction(
                    name: action.name,
                    inputs: mapPropertiesToInput(payloadTypeInfo.properties)
                )
            }
        ))
        
        bag += merge(store.stateSignal.plain(), websocketConnect.map { _ in store.stateSignal.value }.plain()).onValue({ value in
            self.websocketSessions.forEach { session in
                guard let data = try? JSONEncoder().encode(store.stateSignal.value), let jsonString = String(data: data, encoding: .utf8) else {
                    return
                }
                
                let response = StateWebsocketResponse(
                    name: String(describing: store),
                    state: jsonString
                )
                
                guard let data = try? JSONEncoder().encode(response), let jsonString = String(data: data, encoding: .utf8) else {
                    return
                }
                                
                session.writeText(jsonString)
            }
        })
        
        let storeName = String(describing: store)
        
        bag += store.actionSignal.onValue { action in
            let json = try? JSONEncoder().encode(action)
            let any = try! JSONSerialization.jsonObject(with: json!, options: [])
            
            if let actionHistoryArray = self.actionHistory[storeName] {
                self.actionHistory[storeName] = [actionHistoryArray, [[String(Date().timeIntervalSince1970): any]]].flatMap { $0 }
            } else {
                self.actionHistory[storeName] = [[String(Date().timeIntervalSince1970): any]]
            }
        }
    }
    
    let server = HttpServer()
    let networkLogger = NetworkLogger()
    
    public func startServer() {
        sharedPresentableStoreDebugger = self
        URLSessionProxyDelegate.exhangeDelegateImplementation()
        
        server["/stores"] = { request in
            let encoded = try! JSONEncoder().encode(self.container)
            return HttpResponse.ok(.data(encoded, contentType: "application/json"))
        }
        
        server["/history"] = { request in
            let history = try! JSONSerialization.data(withJSONObject: ["history": self.actionHistory], options: [])
            return HttpResponse.ok(.data(history, contentType: "application/json"))
        }
        
        server["/network"] = { request in
            let encoded = try! JSONEncoder().encode(self.networkLogger)
            return HttpResponse.ok(.data(encoded, contentType: "application/json"))
        }
        
        server["/state"] = websocket(text: nil, binary: nil, pong: { session, _ in
            session.writeText("PONG")
        }, connected: { session in
            self.websocketSessions.append(session)
            self.websocketConnect.callAll()
        }, disconnected: { session in
            self.websocketSessions = Array(
                self.websocketSessions.drop { storedSession in
                    session == storedSession
                }
            )
        })
        
        server.post["/send"] = { request in
            let jsonString = String(bytes: request.body, encoding: .utf8)
            
            let jsonObject = try! JSONSerialization.jsonObject(with: jsonString!.data(using: .utf8)!, options: []) as! [String: Any]
            let storeName = jsonObject["store"] as! String
            let action = jsonObject["action"]!
            
            let actionData = try! JSONSerialization.data(withJSONObject: action, options: [])
            
            self.decodeAndSenders[storeName]!(actionData)
            
            return HttpResponse.ok(.text("OK"))
        }
        
        try? server.start(3040, forceIPv4: true, priority: .userInitiated)
    }
}
