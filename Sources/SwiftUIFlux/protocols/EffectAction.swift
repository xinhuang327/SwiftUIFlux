//
//  File.swift
//  
//
//  Created by HuangXin on 2021/12/25.
//

import Foundation

/// Action that support async function
/// `execute` will be called after `Reducer` processed
open class EffectAction: NSObject, Action {
	
	/// NOTE: Catch any error in the function body, or the error may be lost and ignored.
	open func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async throws {
		
	}
	
	/// Called when execution completes, with error if any.
	open func completed(error: Error?) {
		if let error = error {
			print("\(type(of: self)) Error in effect executing: \(error)")
//			fatalError("\(type(of: self)) Error in effect executing: \(error)")
		}
	}
}

/// Effect Action with an `Output` return value
//open class OutputEffectAction<Output>: EffectAction {
//
//	open override func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async throws {
//
//	}
//
////	open func executeWithOutput(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async throws -> Output {
////
////	}
//
//
//}


/// For testing error throwing
public struct SimpleError: Error {
	let errorMessage: String
}

/// For testing error throwing
public class ThrowErrorEffect: EffectAction {
	public override func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async throws {
		try await Task.sleep(seconds: 5)
		throw SimpleError(errorMessage: "Error message from ThrowErrorEffect")
	}
}

