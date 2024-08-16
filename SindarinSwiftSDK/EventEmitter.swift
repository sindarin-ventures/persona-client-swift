//
//  EventEmitter.swift
//  SindarinSwiftSDK
//
//  Created by MacBook on 15.08.2024.
//

import Foundation

class EventEmitter: NSObject {
    private var listeners = [String: [(Any?) -> Void]]()
    
    func on(event: String, handler: @escaping (Any?) -> Void) {
        if listeners[event] != nil {
            listeners[event]?.append(handler)
        } else {
            listeners[event] = [handler]
        }
    }
    
    func emit(event: String, data: Any?) {
        if let eventListeners = listeners[event] {
            for listener in eventListeners {
                listener(data)
            }
        }
    }
    
    func off(event: String) {
        listeners[event]?.removeAll()
    }

}
