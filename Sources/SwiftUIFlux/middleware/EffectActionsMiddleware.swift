//
//  File.swift
//  
//
//  Created by HuangXin on 2021/12/25.
//

import Foundation

internal class EffectDispatchManager {
	
	static var shared = {
		return EffectDispatchManager()
	}()
	
	var effectCompletionNotifiers = [NSObject: DispatchSemaphore]()
	var effectOutputs = [NSObject: Any?]()
	var effectErrors = [NSObject: Error?]()
}


/// is async, will return new state after executed
public typealias EffectDispatchFunction = (_ effect: EffectActionBase) async -> (Any?, Error?)


public let effectActionsMiddleware: Middleware<FluxState> = { dispatch, getState in
	
	let effectDispatch = getEffectDispatch(dispatch: dispatch, getState: getState)
	
	return { next in
		return { action in
			if let effect = action as? EffectActionBase {
				print("before \(effect) async Task")
				Task {
					print("In effect \(effect) async Task")
					let (anyOutput, anyError) = await effect.execute(state: getState(), dispatch: dispatch, effectDispatch: effectDispatch)
					effect.completed(output: anyOutput, error: anyError)
					print("effect completed")
					if let mutex = EffectDispatchManager.shared.effectCompletionNotifiers[effect] {
						// if there is a effectDispatch waiting, passing error if any, and signal it
						EffectDispatchManager.shared.effectOutputs[effect] = anyOutput
						EffectDispatchManager.shared.effectErrors[effect] = anyError
						print("mutex.signal()", type(of: effect))
						mutex.signal()
					}
				}
			}
			return next(action)
		}
	}
}



internal func getEffectDispatch(dispatch: @escaping DispatchFunction, getState: @escaping () -> FluxState?) -> EffectDispatchFunction {
	
	let effectDispatch: EffectDispatchFunction = { (effect) async -> (Any?, Error?) in
		
		let mutex = DispatchSemaphore(value: 0)
		EffectDispatchManager.shared.effectCompletionNotifiers[effect] = mutex
		
		dispatch(effect) // dispatch in regular wait
		
		return await withCheckedContinuation { (continuation) in
			// Use another DispatchQueue for the job, or it will blocking main queue.
			DispatchQueue.global().async {
				//
				if let mutex = EffectDispatchManager.shared.effectCompletionNotifiers[effect] {
					print("Now waiting at mutex.wait()")
					mutex.wait()
					print("after mutex.wait(), removing mutex", type(of: effect))
					EffectDispatchManager.shared.effectCompletionNotifiers.removeValue(forKey: effect)
				}
				if let anyOutput = EffectDispatchManager.shared.effectOutputs[effect], let anyError = EffectDispatchManager.shared.effectErrors[effect] {
					// NOTE: anyOutput is Optional<Any>, anyOutput is Optional<Error>
					continuation.resume(returning: (anyOutput, anyError))
				}
				EffectDispatchManager.shared.effectOutputs.removeValue(forKey: effect)
				EffectDispatchManager.shared.effectErrors.removeValue(forKey: effect)
				
				print("EffectDispatchManager.shared.effectCompletionNotifiers.count", EffectDispatchManager.shared.effectCompletionNotifiers.count)
				print("EffectDispatchManager.shared.effectOutputs.count", EffectDispatchManager.shared.effectOutputs.count)
				print("EffectDispatchManager.shared.effectErrors.count", EffectDispatchManager.shared.effectErrors.count)
				
			}
		}
	}
	
	return effectDispatch
}


extension Store {
	
	func effectDispatch(_ effect: EffectActionBase) async -> (Any?, Error?) {
		let dispatch: (Action) -> Void = { [weak self] in self?.dispatch(action: $0) }
		let getState = { [weak self] in self?.state }
		
		let effectDispatch = getEffectDispatch(dispatch: dispatch, getState: getState)
		return await effectDispatch(effect)
	}
}
