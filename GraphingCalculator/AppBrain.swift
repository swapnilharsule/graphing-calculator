//
//  AppBrain.swift
//  Calcmaster
//
//  Created by Swapnil Harsule on 7/18/16.
//  Copyright © 2016 Swapnil Harsule. All rights reserved.
//

import Foundation

class CalcBrain {
    
    private var accumulator = 0.0
    private var isConstant = false
    
    typealias PropertyList = AnyObject
    private var internalProgram = [PropertyList]()
    
    private var operations: Dictionary<String, Operation> = [
        
        "eˣ"    :Operation.unaryOperation( { pow(M_E, $0) }, "e^", false),
        "10ˣ"   :Operation.unaryOperation( { pow(10, $0) }, "10^", false),
        "logₑ"  :Operation.unaryOperation( { log($0) }, "logₑ", false),
        "log₁₀" :Operation.unaryOperation( { log10($0) }, "log₁₀", false),
        "x²"    :Operation.unaryOperation( { pow($0,2) }, "²", true),
        "√"     :Operation.unaryOperation(sqrt, "√", false),
        "x³"    :Operation.unaryOperation( { pow($0,3) }, "³", true ),
        "³√"    :Operation.unaryOperation( { pow($0,1/3) }, "³√", false ),
        "cos"   :Operation.unaryOperation(cos, "cos", false),
        "sin"   :Operation.unaryOperation(sin, "sin", false),
        "tan"   :Operation.unaryOperation(tan, "tan", false),
        "π"     :Operation.constant(M_PI),
        "AC"    :Operation.clear,
        "1/x"   :Operation.unaryOperation( { 1/$0 } ,"⁻¹", true),
        "⁺⁄₋"   :Operation.unaryOperation( { -$0 } ,"-", false),
        "%"     :Operation.binaryOperation( { $0%$1 } ),
        "×"     :Operation.binaryOperation( { $0 * $1 } ),
        "+"     :Operation.binaryOperation( { $0 + $1 } ),
        "-"     :Operation.binaryOperation( { $0 - $1 } ),
        "÷"     :Operation.binaryOperation( { $0 / $1 } ),
        "="     :Operation.equals
    ]
    
    private var variableValues: Dictionary<String, Double> = [:]
    private var isOperandVar = false
    
    func SetVariableValue(varName: String, varValue: Double) {
        variableValues[varName] = varValue
    }
    
    func GetVariableValue(varName: String) -> Double? {
        return variableValues[varName]
    }
    
    private enum Operation {
        
        case constant(Double)
        case unaryOperation((Double)->Double, String, Bool) // TRUE mean symbol suffixed, FALSE means prefixed
        case binaryOperation((Double, Double)->Double)
        case equals
        case clear
    }
    
    var program : PropertyList {
        get{
            return internalProgram as CalcBrain.PropertyList
        }
        set{
            ResetCalculator()
            if let arrayOfOps = newValue as? [AnyObject] {
                for op in arrayOfOps{
                    
                    if let operand = op as? Double {
                        SetOperand(operand)
                    }
                    else if let operation = op as? String{
                        
                        if variableValues[operation] != nil {
                            SetOperand(operation)
                        }
                        else {
                            PerformOperation(operation)
                        }
                    }
                }
            }
            
        }
    }
    
    var result : Double {
        
        get {
            return accumulator
        }
    }
    
    var description: String {
        get{
            if isPartialResult { return operationsTyped + "..." }
            else if operationsTyped == " " { return operationsTyped }
            else { return operationsTyped + "=" }
        }
    }
    
    private var operationsTyped:String = " "
    
    private struct PendingBinaryOperation {
        
        var binaryFunc: (Double, Double)->Double
        var firstOperand: Double
    }
    
    func formatNumber(value: Double) -> String? {

        let formatter = NSNumberFormatter()
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.minimumIntegerDigits = 1

        if let retString = formatter.stringFromNumber(NSNumber(double: value)) {
            return retString
        }
        return nil
    }
    
    private var isPending: PendingBinaryOperation?
    
    var isPartialResult: Bool {
        get{
            return isPending != nil
        }
    }
    
    private func ClearDescription() {
        operationsTyped = " "
    }
    
    func SetOperand(varName: String) {
        
        if variableValues[varName] == nil {
            SetVariableValue(varName, varValue: 0.0)
        }
        internalProgram.append(varName as CalcBrain.PropertyList)
        accumulator = variableValues[varName]!
        if(!isPartialResult) {
            operationsTyped = varName
        }
        else {
            operationsTyped += varName
            isOperandVar = true
        }
    }
    
    func SetOperand(operand: Double) {
        
        accumulator = operand
        internalProgram.append(operand as CalcBrain.PropertyList)
        if(!isPartialResult) {
            operationsTyped = formatNumber(accumulator)!
        }

    }
    
    func PerformOperation (symbol: String) {
        
        var textToAppend:String
        
        if let operation = operations[symbol] {
            internalProgram.append(symbol as CalcBrain.PropertyList)
            
            switch operation {
            
            case .constant(let value):
                if(isPartialResult) {
                    operationsTyped += String(symbol)
                }
                else {
                    ClearDescription()
                    operationsTyped = String(symbol)
                }
                accumulator = value
                isConstant = true
                
            case .unaryOperation(let function, let symbolToPrint, let suffix):
                if(isPartialResult) {
                    if isConstant == true {
                        textToAppend = String(operationsTyped.removeAtIndex(operationsTyped.endIndex.predecessor()))
                    }
                    else {
                        textToAppend = formatNumber(accumulator)!
                    }
                    isConstant = true
                    if suffix{
                        operationsTyped += "(" + textToAppend + ")" + String(symbolToPrint)
                    }
                    else {
                        operationsTyped += String(symbolToPrint) + "(" + textToAppend + ")"
                    }
                }
                else {
                    if operationsTyped != " "{
                        textToAppend = operationsTyped
                    } else {
                        textToAppend = formatNumber(accumulator)!
                    }
                    if suffix{
                        operationsTyped = "(" + textToAppend + ")" + String(symbolToPrint)
                    }
                    else {
                        operationsTyped = String(symbolToPrint) + "(" + textToAppend + ")"
                    }
                }
                
                accumulator = function(accumulator)
                
            case .binaryOperation(let function):
                execPendingBinaryOperation()
                operationsTyped +=  String(symbol)
                isPending = PendingBinaryOperation(binaryFunc:  function, firstOperand:   accumulator)
            
            case .equals:
                execPendingBinaryOperation()
                
            case .clear:
                variableValues["M"] = nil
                ResetCalculator()
            }
        }
    }
    
    func UndoLast() {
        if internalProgram.count > 0 {
            internalProgram.removeLast()
            program = internalProgram as CalcBrain.PropertyList
        }
        
    }
    
    private func execPendingBinaryOperation() {
        if isPending != nil {
            if(!isConstant && !isOperandVar) {
                operationsTyped += formatNumber(accumulator)!
            }
            else {
                isConstant = false
                isOperandVar = false
            }
            
            accumulator = (isPending!.binaryFunc(isPending!.firstOperand, accumulator))
            isPending = nil
        }
    }
    
    private func ResetCalculator() {
        isPending = nil
        accumulator = 0
        ClearDescription()
        internalProgram.removeAll()
    }
    
}
