//
//  CCPArchiveUtil.swift
//  CCPArchive
//
//  Created by 储诚鹏 on 2019/12/13.
//  Copyright © 2019 储诚鹏. All rights reserved.
//

import Zip
import Foundation

public typealias ProgressCallback = (_ progress: Progress) -> ()
public typealias CompletedCallback = () -> ()
public typealias Destination = URL

public enum ZipOption {
    case `default`
    case none
    case bestSpeed
    case bestCompression
}

extension ZipOption {
     var zip: Int32 {
        switch self {
        case .default:
            return Z_DEFAULT_COMPRESSION
        case .bestSpeed:
            return Z_BEST_SPEED
        case .bestCompression:
            return Z_BEST_COMPRESSION
        case .none:
            return Z_NO_COMPRESSION
        }
    }
}

public protocol CCPArchiveSource {
    func url() throws -> URL
}

extension String: CCPArchiveSource {
    public func url() throws -> URL {
        return URL(fileURLWithPath: self)
    }
}

extension URL: CCPArchiveSource {
    public func url() throws -> URL {
        return self
    }
}

extension Optional where Wrapped: CCPArchiveSource {
    public func url() throws -> URL {
        switch self {
        case .some(let v):
            return try v.url()
        default:
            throw ZipError.emptySource
        }
    }
}
