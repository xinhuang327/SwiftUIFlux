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
	
	var effectCompletionNotifiers = [EffectAction: DispatchSemaphore]()
	var effectErrors = [EffectAction: Error?]()
}


/// is async, will return new state after executed
public typealias EffectDispatchFunction = (_ effect: EffectAction) async throws -> FluxState?

/// is async, will return Generic type `Output` after executed
//public typealias OutputEffectDispatchFunction<Output> = (_ effect: EffectAction) async throws -> FluxState?

public let effectActionsMiddleware: Middleware<FluxState> = { dispatch, getState in
	
	let effectDispatch = getEffectDispatch(dispatch: dispatch, getState: getState)
	
	return { next in
		return { action in
			if let effect = action as? EffectAction {
				print("before \(effect) async Task")
				Task {
					print("In effect \(effect) async Task")
					var anyError: Error?
					do {
						try await effect.execute(state: getState(), dispatch: dispatch, effectDispatch: effectDispatch)
					} catch {
						anyError = error
					}
					effect.completed(error: anyError)
					print("effect completed")
					if let mutex = EffectDispatchManager.shared.effectCompletionNotifiers[effect] {
						// if there is a effectDispatch waiting, passing error if any, and signal it
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
	
	let effectDispatch: EffectDispatchFunction = { (effect) async throws -> FluxState? in
		let mutex = DispatchSemaphore(value: 0)
		EffectDispatchManager.shared.effectCompletionNotifiers[effect] = mutex
		
		dispatch(effect) // dispatch in regular wait
		
		return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FluxState?, Error>) in
			// Use another DispatchQueue for the job, or it will blocking main queue.
			DispatchQueue.global().async {
				//
				if let mutex = EffectDispatchManager.shared.effectCompletionNotifiers[effect] {
					print("Now waiting at mutex.wait()")
					mutex.wait()
					print("after mutex.wait(), removing mutex", type(of: effect))
					EffectDispatchManager.shared.effectCompletionNotifiers.removeValue(forKey: effect)
				}
				if let anyError = EffectDispatchManager.shared.effectErrors[effect], let error = anyError {
					continuation.resume(throwing: error)
					EffectDispatchManager.shared.effectErrors.removeValue(forKey: effect)
				} else {
					continuation.resume(returning: getState())
				}
			}
		}
	}
	
	return effectDispatch
}


extension Store {
	
	func effectDispatch(_ effect: EffectAction) async throws -> FluxState? {
		let dispatch: (Action) -> Void = { [weak self] in self?.dispatch(action: $0) }
		let getState = { [weak self] in self?.state }
		
		let effectDispatch = getEffectDispatch(dispatch: dispatch, getState: getState)
		return try await effectDispatch(effect)
	}
}
