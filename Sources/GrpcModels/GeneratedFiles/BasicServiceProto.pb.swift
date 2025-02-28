// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: com/octopuscommunity/BasicServiceProto.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

public struct Com_Octopuscommunity_HelloResponse: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  public var version: String = String()

  ///Present only for octopus admin
  public var shortCommitHash: String {
    get {return _shortCommitHash ?? String()}
    set {_shortCommitHash = newValue}
  }
  /// Returns true if `shortCommitHash` has been explicitly set.
  public var hasShortCommitHash: Bool {return self._shortCommitHash != nil}
  /// Clears the value of `shortCommitHash`. Subsequent reads from it will return its default value.
  public mutating func clearShortCommitHash() {self._shortCommitHash = nil}

  public var fullCommitHash: String {
    get {return _fullCommitHash ?? String()}
    set {_fullCommitHash = newValue}
  }
  /// Returns true if `fullCommitHash` has been explicitly set.
  public var hasFullCommitHash: Bool {return self._fullCommitHash != nil}
  /// Clears the value of `fullCommitHash`. Subsequent reads from it will return its default value.
  public mutating func clearFullCommitHash() {self._fullCommitHash = nil}

  public var githubLink: String {
    get {return _githubLink ?? String()}
    set {_githubLink = newValue}
  }
  /// Returns true if `githubLink` has been explicitly set.
  public var hasGithubLink: Bool {return self._githubLink != nil}
  /// Clears the value of `githubLink`. Subsequent reads from it will return its default value.
  public mutating func clearGithubLink() {self._githubLink = nil}

  public var uncommitted: String {
    get {return _uncommitted ?? String()}
    set {_uncommitted = newValue}
  }
  /// Returns true if `uncommitted` has been explicitly set.
  public var hasUncommitted: Bool {return self._uncommitted != nil}
  /// Clears the value of `uncommitted`. Subsequent reads from it will return its default value.
  public mutating func clearUncommitted() {self._uncommitted = nil}

  public var protoShortCommitHash: String {
    get {return _protoShortCommitHash ?? String()}
    set {_protoShortCommitHash = newValue}
  }
  /// Returns true if `protoShortCommitHash` has been explicitly set.
  public var hasProtoShortCommitHash: Bool {return self._protoShortCommitHash != nil}
  /// Clears the value of `protoShortCommitHash`. Subsequent reads from it will return its default value.
  public mutating func clearProtoShortCommitHash() {self._protoShortCommitHash = nil}

  public var protoFullCommitHash: String {
    get {return _protoFullCommitHash ?? String()}
    set {_protoFullCommitHash = newValue}
  }
  /// Returns true if `protoFullCommitHash` has been explicitly set.
  public var hasProtoFullCommitHash: Bool {return self._protoFullCommitHash != nil}
  /// Clears the value of `protoFullCommitHash`. Subsequent reads from it will return its default value.
  public mutating func clearProtoFullCommitHash() {self._protoFullCommitHash = nil}

  public var protoGithubLink: String {
    get {return _protoGithubLink ?? String()}
    set {_protoGithubLink = newValue}
  }
  /// Returns true if `protoGithubLink` has been explicitly set.
  public var hasProtoGithubLink: Bool {return self._protoGithubLink != nil}
  /// Clears the value of `protoGithubLink`. Subsequent reads from it will return its default value.
  public mutating func clearProtoGithubLink() {self._protoGithubLink = nil}

  public var protoUncommitted: String {
    get {return _protoUncommitted ?? String()}
    set {_protoUncommitted = newValue}
  }
  /// Returns true if `protoUncommitted` has been explicitly set.
  public var hasProtoUncommitted: Bool {return self._protoUncommitted != nil}
  /// Clears the value of `protoUncommitted`. Subsequent reads from it will return its default value.
  public mutating func clearProtoUncommitted() {self._protoUncommitted = nil}

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  public init() {}

  fileprivate var _shortCommitHash: String? = nil
  fileprivate var _fullCommitHash: String? = nil
  fileprivate var _githubLink: String? = nil
  fileprivate var _uncommitted: String? = nil
  fileprivate var _protoShortCommitHash: String? = nil
  fileprivate var _protoFullCommitHash: String? = nil
  fileprivate var _protoGithubLink: String? = nil
  fileprivate var _protoUncommitted: String? = nil
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "com.octopuscommunity"

extension Com_Octopuscommunity_HelloResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".HelloResponse"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    4: .same(proto: "version"),
    1: .same(proto: "shortCommitHash"),
    2: .same(proto: "fullCommitHash"),
    3: .same(proto: "githubLink"),
    5: .same(proto: "uncommitted"),
    11: .same(proto: "protoShortCommitHash"),
    12: .same(proto: "protoFullCommitHash"),
    13: .same(proto: "protoGithubLink"),
    15: .same(proto: "protoUncommitted"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self._shortCommitHash) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self._fullCommitHash) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self._githubLink) }()
      case 4: try { try decoder.decodeSingularStringField(value: &self.version) }()
      case 5: try { try decoder.decodeSingularStringField(value: &self._uncommitted) }()
      case 11: try { try decoder.decodeSingularStringField(value: &self._protoShortCommitHash) }()
      case 12: try { try decoder.decodeSingularStringField(value: &self._protoFullCommitHash) }()
      case 13: try { try decoder.decodeSingularStringField(value: &self._protoGithubLink) }()
      case 15: try { try decoder.decodeSingularStringField(value: &self._protoUncommitted) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._shortCommitHash {
      try visitor.visitSingularStringField(value: v, fieldNumber: 1)
    } }()
    try { if let v = self._fullCommitHash {
      try visitor.visitSingularStringField(value: v, fieldNumber: 2)
    } }()
    try { if let v = self._githubLink {
      try visitor.visitSingularStringField(value: v, fieldNumber: 3)
    } }()
    if !self.version.isEmpty {
      try visitor.visitSingularStringField(value: self.version, fieldNumber: 4)
    }
    try { if let v = self._uncommitted {
      try visitor.visitSingularStringField(value: v, fieldNumber: 5)
    } }()
    try { if let v = self._protoShortCommitHash {
      try visitor.visitSingularStringField(value: v, fieldNumber: 11)
    } }()
    try { if let v = self._protoFullCommitHash {
      try visitor.visitSingularStringField(value: v, fieldNumber: 12)
    } }()
    try { if let v = self._protoGithubLink {
      try visitor.visitSingularStringField(value: v, fieldNumber: 13)
    } }()
    try { if let v = self._protoUncommitted {
      try visitor.visitSingularStringField(value: v, fieldNumber: 15)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Com_Octopuscommunity_HelloResponse, rhs: Com_Octopuscommunity_HelloResponse) -> Bool {
    if lhs.version != rhs.version {return false}
    if lhs._shortCommitHash != rhs._shortCommitHash {return false}
    if lhs._fullCommitHash != rhs._fullCommitHash {return false}
    if lhs._githubLink != rhs._githubLink {return false}
    if lhs._uncommitted != rhs._uncommitted {return false}
    if lhs._protoShortCommitHash != rhs._protoShortCommitHash {return false}
    if lhs._protoFullCommitHash != rhs._protoFullCommitHash {return false}
    if lhs._protoGithubLink != rhs._protoGithubLink {return false}
    if lhs._protoUncommitted != rhs._protoUncommitted {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
