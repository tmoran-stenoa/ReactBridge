//
//  ReactMethod.swift
//
//  Created by Iurii Khvorost <iurii.khvorost@gmail.com> on 2023/07/24.
//  Copyright © 2023 Iurii Khvorost. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics


public struct ReactMethod {
}

extension ReactMethod: PeerMacro {
  
  private static func reactExport(funcName: String, jsName: String, objcName: String, isSync: Bool) -> DeclSyntax {
    """
    @objc static func __rct_export__\(raw: funcName)() -> UnsafePointer<RCTMethodInfo>? {
      struct Static {
        static var methodInfo = RCTMethodInfo(
          jsName: NSString(string:"\(raw: jsName)").utf8String,
          objcName: NSString(string:"\(raw: objcName)").utf8String,
          isSync: \(raw: isSync)
        )
      }
      return withUnsafePointer(to: &Static.methodInfo) { $0 }
    }
    """
  }
  
  private static func objcSelector(funcDecl: FunctionDeclSyntax) throws -> String {
    var selector = "\(funcDecl.name.trimmed)"
    
    let parameterList = funcDecl.signature.parameterClause.parameters
    for param in parameterList {
      let objcType = try param.type.objcType(isRoot: true)
      var firstName = "\(param.firstName.trimmed)"
      
      if param == parameterList.first {
        if firstName != "_" {
          if param.secondName == nil {
            selector += "With\(firstName.capitalized):(\(objcType))\(firstName)"
            continue
          }
          else {
            firstName = firstName.capitalized
          }
        }
      }
      else {
        selector += " "
      }
      
      firstName = firstName == "_" ? "" : firstName
      let secondName = param.secondName != nil ? "\(param.secondName!.trimmed)" : firstName
      selector += "\(firstName):(\(objcType))\(secondName)"
    }
    
    return selector
  }
  
  private static func verifyType(type: TypeSyntax) throws {
    if let simpleType = type.as(IdentifierTypeSyntax.self), simpleType.genericArgumentClause == nil {
      let swiftType = "\(simpleType.trimmed)"
      guard let objcType = ObjcType(swiftType: swiftType) else {
        throw SyntaxError(sytax: simpleType._syntaxNode, message: ErrorMessage.unsupportedType(typeName: swiftType))
      }
      if objcType.kind != .object {
        // Warning: non class return type
        throw SyntaxError(sytax: type._syntaxNode, message: ErrorMessage.nonClassReturnType)
      }
    }
    else {
      let _ = try type.objcType()
    }
  }
  
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext)
  throws -> [DeclSyntax]
  {
    do {
      // Error: func
      guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
        throw SyntaxError(sytax: declaration._syntaxNode, message: ErrorMessage.funcOnly(macroName: "\(self)"))
      }
      
      // Error: @objc
      guard let attributes = funcDecl.attributes?.as(AttributeListSyntax.self),
            attributes.first(where: { $0.description.contains("@objc") }) != nil
      else {
        let funcName = "\(funcDecl.name.trimmed)"
        throw SyntaxError(sytax: funcDecl._syntaxNode, message: ErrorMessage.objcOnly(funcName: funcName))
      }
    
      let objcName = try objcSelector(funcDecl: funcDecl)
      let funcName = "\(funcDecl.name.trimmed)"
      
      let arguments = node.arguments()
      let jsName = (arguments?["jsName"] as? String) ?? funcName
      let isSync = (arguments?["isSync"] as? Bool) == true
      
      // Return type
      if let returnType = funcDecl.signature.returnClause?.type {
        if isSync == false {
          // Warning: isSync
          let diagnostic = Diagnostic(node: node._syntaxNode, message: ErrorMessage.nonSync)
          context.diagnose(diagnostic)
        }
        try verifyType(type: returnType)
      }
      
      return [
        reactExport(funcName: funcName, jsName: jsName, objcName: objcName, isSync: isSync)
      ]
    }
    catch let error as SyntaxError {
      let diagnostic = Diagnostic(node: error.sytax, message: error.message)
      context.diagnose(diagnostic)
      
      return []
    }
  }
}
