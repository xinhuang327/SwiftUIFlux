//
//  AppState.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 06/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

final public class Store<StoreState: FluxState>: ObservableObject {
    @Published public var state: StoreState

    private var dispatchFunction: DispatchFunction!
    private let reducer: Reducer<StoreState>
    
    public init(reducer: @escaping Reducer<StoreState>,
                middleware: [Middleware<StoreState>] = [],
                state: StoreState) {
        self.reducer = reducer
        self.state = state
        
        var middleware = middleware
		middleware.append(asyncActionsMiddleware)
		middleware.append(effectActionsMiddleware)
        self.dispatchFunction = middleware
            .reversed()
            .reduce(
                { [unowned self] action in
                    self._dispatch(action: action) },
                { dispatchFunction, middleware in
                    let dispatch: (Action) -> Void = { [weak self] in self?.dispatch(action: $0) }
                    let getState = { [weak self] in self?.state }
                    return middleware(dispatch, getState)(dispatchFunction)
            })
    }
	
	/// must to use a queue, or actions would be disordered
	private var dispatchQueue = DispatchQueue(label: "reduxDispatchQ", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem, target: .main)

    public func dispatch(action: Action) {
		/// check out the issue: https://github.com/Dimillian/SwiftUIFlux/issues/18
		DispatchQueue.main.async {
			self.objectWillChange.send() // use this to fix inconsistent state, more investigation needed.
			self.dispatchFunction(action)
		}
    }
    
    private func _dispatch(action: Action) {
        state = reducer(state, action)
    }
}
