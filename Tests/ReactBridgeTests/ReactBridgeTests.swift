import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import ReactBridgeMacros
import ReactBridge


//let macros: [String: Macro.Type] = [
//  "ReactModule": ReactModule.self,
//  "ReactMethod": ReactMethod.self,
//  "ReactViewProperty": ReactViewProperty.self
//]

@ReactModule()
class A: NSObject {

//  @ReactMethod(isSync: true)
//  @objc func test(text: CGColor) -> Int {
//    return 200
//  }
}

final class ReactMethodTests: XCTestCase {
  
  let macros: [String: Macro.Type] = [
    "ReactMethod": ReactMethod.self,
  ]
  
  func test_error_funcOnly() {
    assertMacroExpansion(
      """
      class A {
        @ReactMethod
        @objc func test(text: String) -> Int {
          return 200
        }
      }
      """,
      expandedSource:
      """
      """,
      macros: macros
    )
  }
}

final class ReactModuleTests: XCTestCase {
  
  let macros: [String: Macro.Type] = [
    "ReactModule": ReactModule.self,
  ]
  
  func test_error_classOnly() {
    let diagnostic = DiagnosticSpec(message: ReactModule.Message.classOnly.message, line: 1, column: 1)
        
    assertMacroExpansion(
      """
      @ReactModule
      struct A {
      }
      """,
      expandedSource:
      """
      struct A {
      }
      """,
      diagnostics: [diagnostic, diagnostic],
      macros: macros
    )
  }
  
  func test_error_inheritNSObject() {
    let diagnostic = DiagnosticSpec(message: ReactModule.Message.inheritNSObject(name: "A").message, line: 1, column: 1)
    
    assertMacroExpansion(
      """
      @ReactModule
      class A {
      }
      """,
      expandedSource:
      """
      class A {
      }
      """,
      diagnostics: [diagnostic, diagnostic],
      macros: macros
    )
  }
  
  func test() {
    assertMacroExpansion(
      """
      @ReactModule
      class A: NSObject {
      }
      """,
      expandedSource:
      """
      class A: NSObject {
          @objc static func moduleName() -> String! {
            "\\(self)"
          }
          @objc static func _registerModule() {
            RCTRegisterModule(self);
          }
      }
      extension A: RCTBridgeModule {
      }
      """,
      macros: macros
    )
  }
}

