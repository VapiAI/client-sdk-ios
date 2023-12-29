//
//  WebCallResponse.swift
//
//
//  Created by Andrew Carter on 12/13/23.
//

import Foundation

public struct WebCallResponse: Decodable {
    let webCallUrl: URL
    let id: String
}
