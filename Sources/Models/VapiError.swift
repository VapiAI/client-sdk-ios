//
//  VapiError.swift
//  
//
//  Created by Andrew Carter on 12/13/23.
//

import Foundation

public enum VapiError: Swift.Error {
    case invalidURL
    case customError(String)
    case existingCallInProgress
    case noCallInProgress
}
