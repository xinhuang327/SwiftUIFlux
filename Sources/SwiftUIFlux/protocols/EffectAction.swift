//
//  File.swift
//  
//
//  Created by HuangXin on 2021/12/25.
//

import Foundation

/// Demo usage of strong typed EffectAction<String>
class SomeEffectReturnsString: EffectAction<String> {
	
	override func executeStrongTyped(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: StrongTypedEffectDispatcher) async -> (String?, Error?) {
		return ("Good", nil)
	}
	
}

open class StrongTypedEffectDispatcher {
	
	var effectDispatch: EffectDispatchFunction
	
	public init(effectDispatch: @escaping EffectDispatchFunction) {
		self.effectDispatch = effectDispatch
	}
	
	public init(_ dispatch: @escaping DispatchFunction) {
		self.effectDispatch = getEffectDispatch(dispatch: dispatch)
	}
	
	open func dispatch<T>(_ effect: EffectAction<T>) async -> (T?, Error?) {
		let effectDispatchStrongTyped = getEffectDispatchStrongTyped(forEffect: effect, effectDispatch)
		return await effectDispatchStrongTyped(effect)
	}
	
	open func dispatchAny(_ effect: EffectActionBase) async -> (Any?, Error?) {
		return await effectDispatch(effect)
	}
}

open class EffectAction<Output>: EffectActionBase {
	
	open override func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async -> (Any?, Error?) {
		return await executeStrongTyped(state: state, dispatch: dispatch, effectDispatch: StrongTypedEffectDispatcher(effectDispatch: effectDispatch))
	}
	
	open func executeStrongTyped(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: StrongTypedEffectDispatcher) async -> (Output?, Error?) {
		// dispatch sub effects:
		// dispatcher.dispatch(SomeEffect())
		return (nil, nil)
	}
}

/// Action that support async function
/// `execute` will be called after `Reducer` processed
open class EffectActionBase: NSObject, Action {
	
	/// NOTE: Effect's execute function returns both result and error, like Golang's function
	open func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async -> (Any?, Error?) {
		return (nil, nil)
	}
	
	/// Called when execution completes, with error if any.
	open func completed(output: Any?, error: Error?) {
		if let error = error {
			print("\(type(of: self)) Error in effect executing: \(error)")
			//			fatalError("\(type(of: self)) Error in effect executing: \(error)")
		}
	}
}


/// For testing error throwing
public struct SimpleError: Error {
	let errorMessage: String
}

/// For testing error throwing
public class ThrowErrorEffect: EffectActionBase {
	
	public override func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async -> (Any?, Error?) {
		try! await Task.sleep(seconds: 5)
		return (nil, SimpleError(errorMessage: "Error message from ThrowErrorEffect"))
	}
}

