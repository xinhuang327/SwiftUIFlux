#if DEBUG
import XCTest
import SwiftUI
@testable import SwiftUIFlux
import simd

struct TestState: FluxState {
    var count = 0
}

struct IncrementAction: Action { }

struct TestError: Error {
	let errorMessage: String
}

class CountingEffect: EffectAction {
	
	internal init(intervalInSecond: Double, count: Int, name: String) {
		self.intervalInSecond = intervalInSecond
		self.count = count
		self.name = name
	}
	
	let intervalInSecond: Double
	let count: Int
	let name: String
	
	
	override func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async throws {
		for i in 0..<count {
			print("\(name) Counting... \(i)")
			try await Task.sleep(seconds: intervalInSecond)
		}
	}
}

class TestEffect: EffectAction {
	
	internal init(sleepInSecond: Double, message: String, error: Error?) {
		self.sleepInSecond = sleepInSecond
		self.message = message
		self.error = error
	}
	
	
	let sleepInSecond: Double
	let message: String
	let error: Error?
	
	override func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async throws {
		print("Now sleep for \(sleepInSecond) seconds")
		try await Task.sleep(seconds: sleepInSecond)
		try await effectDispatch(CountingEffect(intervalInSecond: 1, count: 10, name: "SUB"))
		print("==== Message should be print after SUB counting finished.", message)
	}
}

func testReducer(state: TestState, action: Action) -> TestState {
    var state = state
    switch action {
    case _ as IncrementAction:
        state.count += 1
    default:
        break
    }
	print("Reducer called for action \(type(of: action)) \(action)")
    return state
}

struct HomeView: ConnectedView {
    struct Props {
        let count: Int
        let onIncrementCount: () -> Void
    }
    
    func text(props: Props) -> String{
        return "\(props.count)"
    }
    
    func map(state: TestState, dispatch: @escaping DispatchFunction) -> Props {
        return Props(count: state.count,
                     onIncrementCount: { dispatch(IncrementAction()) })
    }
    
    func body(props: Props) -> some View {
        VStack {
            Text(text(props: props))
            Button(action: props.onIncrementCount) {
                Text("Increment")
            }
        }
    }
}

@available(iOS 13.0, *)
final class SwiftUIFluxTests: XCTestCase {
    let store = Store<TestState>(reducer: testReducer, state: TestState())
	
	func testStore() {
		XCTAssert(store.state.count == 0, "Initial state is not valid")
		store.dispatch(action: IncrementAction())
		DispatchQueue.main.async {
			XCTAssert(self.store.state.count == 1, "Reduced state increment is not valid")
		}
	}
	
	func testEffectAction() {
		
		let expectation = expectation(description: "effect works")
		
		XCTAssert(store.state.count == 0, "Initial state is not valid")
		store.dispatch(action: TestEffect(sleepInSecond: 3, message: "hello from the other side, \(Date())", error: TestError(errorMessage: "My Err Msg")))
		store.dispatch(action: TestEffect(sleepInSecond: 2, message: "hello from the this side, \(Date())", error: nil))
		store.dispatch(action: CountingEffect(intervalInSecond: 1, count: 3, name: "ROOT"))
		print("Actions all dispatched")
			
		wait(for: [expectation], timeout: 100)
	}
    
    func testViewProps() {
        let view = StoreProvider(store: store) {
            HomeView()
        }
        store.dispatch(action: IncrementAction())
        DispatchQueue.main.async {
            var props = view.content().map(state: self.store.state, dispatch: self.store.dispatch(action:))
            XCTAssert(props.count == 1, "View state is not correct")
            props.onIncrementCount()
            DispatchQueue.main.async {
                props = view.content().map(state: self.store.state, dispatch: self.store.dispatch(action:))
                XCTAssert(props.count == 2, "View state is not correct")
            }
            
        }
        
    }

    static var allTests = [
        ("testExample", testStore),
    ]
}
#endif
