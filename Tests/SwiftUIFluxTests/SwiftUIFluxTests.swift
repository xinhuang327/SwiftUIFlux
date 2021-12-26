#if DEBUG
import XCTest
import SwiftUI
@testable import SwiftUIFlux
import simd

struct TestState: FluxState {
    var count = 0
}

struct IncrementAction: Action { }

class CountingEffect: EffectActionBase {
	
	internal init(intervalInSecond: Double, count: Int, name: String) {
		self.intervalInSecond = intervalInSecond
		self.count = count
		self.name = name
	}
	
	let intervalInSecond: Double
	let count: Int
	let name: String
	
	override func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async -> (Any?, Error?) {
		for i in 0..<count {
			print("\(name) Counting... \(i)")
			try! await Task.sleep(seconds: intervalInSecond)
		}
		return (count*count, nil)
	}
}

class TestEffect: EffectActionBase {
	
	internal init(sleepInSecond: Double, message: String, error: Error?) {
		self.sleepInSecond = sleepInSecond
		self.message = message
		self.error = error
	}
	
	
	let sleepInSecond: Double
	let message: String
	let error: Error?
	
	override func execute(state: FluxState?, dispatch: @escaping DispatchFunction, effectDispatch: @escaping EffectDispatchFunction) async -> (Any?, Error?) {
		print("Now sleep for \(sleepInSecond) seconds")
		try! await Task.sleep(seconds: sleepInSecond)
		let count = Int(sleepInSecond)
		let (out, err) = await effectDispatch(CountingEffect(intervalInSecond: 0.3, count: count, name: "SUB"))
		XCTAssert(err == nil)
		if let outNumber = out! as? Int {
			XCTAssert(outNumber == count * count)
		} else {
			XCTFail("CountingEffect output is wrong")
		}
		if let error = error {
			return (nil, error)
		}
		print("==== Message should be print after SUB counting finished.", message)
		return (message.uppercased(), nil)
	}
	
	override func completed(output: Any?, error: Error?) {
		print("TestEffect completed: \(String(describing: output)), \(String(describing: error))")
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
	
	/// Test async-await with `EffectAction`
	func testEffectAction() async {
		
		
		let msg = "hello from the other side"
		let errorMsg = "My Err Msg"
		
		XCTAssert(store.state.count == 0, "Initial state is not valid")
		let (out1, err1)  = await store.effectDispatch(TestEffect(sleepInSecond: 2, message: msg, error: SimpleError(errorMessage: errorMsg)))
		XCTAssert(out1 == nil)
		XCTAssert(err1 != nil)
		if let simpleErr = err1! as? SimpleError {
			XCTAssert(simpleErr.errorMessage == errorMsg)
		} else {
			XCTFail("Should returns the error")
		}
		
		let (out2, err2)  = await store.effectDispatch(TestEffect(sleepInSecond: 4, message: msg, error: nil))
		XCTAssert(err2 == nil)
		XCTAssert(out2 != nil)
		if let str = out2! as? String {
			XCTAssert(str == msg.uppercased())
		} else {
			XCTFail("Should returns the string")
		}
		
		let (out3, err3) = await store.effectDispatch(ThrowErrorEffect())
		XCTAssert(out3 == nil)
		XCTAssert(err3 != nil)
		
		print("Actions all dispatched")
			
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
