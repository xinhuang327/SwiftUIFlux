//
//  File.swift
//  
//
//  Created by HuangXin on 2021/12/25.
//

import Foundation

/// Action that support async function
/// `execute` will be called after `Reducer` processed
public class EffectAction: NSObject, Action {
	
	open func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async throws {
		
	}
	
	open func completed(error: Error?) {
		if let error = error {
			print("\(type(of: self)) Error in effect executing: \(error)")
		}
	}
}


