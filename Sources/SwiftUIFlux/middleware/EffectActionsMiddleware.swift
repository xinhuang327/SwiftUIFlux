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
}


public typealias EffectDispatchFunction = (_ effect: EffectAction) async throws -> Void

public let effectActionsMiddleware: Middleware<FluxState> = { dispatch, getState in
	
	let effectDispatch: EffectDispatchFunction = { (effect) async throws -> Void in
		let mutex = DispatchSemaphore(value: 0)
		EffectDispatchManager.shared.effectCompletionNotifiers[effect] = mutex
		
		dispatch(effect) // dispatch in regular wait
		
		let _ = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
			// Use another DispatchQueue for the job, or it will blocking main queue.
			DispatchQueue.global().async {
				//
				if let mutex = EffectDispatchManager.shared.effectCompletionNotifiers[effect] {
					print("Now waiting at mutex.wait()")
					mutex.wait()
					print("after mutex.wait(), removing mutex")
					EffectDispatchManager.shared.effectCompletionNotifiers.removeValue(forKey: effect)
				}
				continuation.resume(returning: 1)
			}
		}
	}

	
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
						print("mutex.signal()")
						mutex.signal()
					}
				}
			}
			return next(action)
		}
	}
}





