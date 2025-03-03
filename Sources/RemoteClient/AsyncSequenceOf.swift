//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

// These protocols are here because I couldn't create a function that returns `any AsyncSequence<A_GIVEN_TYPE>`.

// Basic trick
public protocol AsyncThrowingIteratorProtocol<Element>: AsyncIteratorProtocol {}

public protocol AsyncNonThrowingIteratorProtocol<Element>: AsyncIteratorProtocol {
  mutating func next() async -> Element?
}

public protocol AsyncSequenceOf<Element>: AsyncSequence {}

public protocol AsyncNonThrowingSequenceOf<Element>: AsyncSequenceOf where Self.AsyncIterator: AsyncNonThrowingIteratorProtocol {}

typealias AsyncStreamAsyncIterator<T> = AsyncStream<T>.AsyncIterator

extension AsyncStreamAsyncIterator: AsyncNonThrowingIteratorProtocol {}

extension AsyncStream: AsyncNonThrowingSequenceOf {}

extension AsyncThrowingStream: AsyncSequenceOf {}

// Support for `.prefix(_ count:Int)`
public typealias AsyncPrefixSequenceIterator<T: AsyncSequence> = AsyncPrefixSequence<T>.Iterator
extension AsyncPrefixSequenceIterator: AsyncThrowingIteratorProtocol {}
extension AsyncPrefixSequenceIterator: AsyncNonThrowingIteratorProtocol where Base: AsyncNonThrowingSequenceOf {
    public mutating func next() async -> Base.Element? {
    /// Looks like a bug in the compiler. It has enough info
    /// to deduce this by itself.
    /// But for now we have to do it manually.
    /// Here we must call the implementation of
    /// `AsyncThrowingIteratorProtocol<Base.Element>.next` on `self`.
    /// But there is no syntax to express something like:
    /// `self.(AsyncThrowingIteratorProtocol.next)()`
    /// At least to my knowlendge.
    /// So instead we erase `self` to the desired protocol via opaque,
    /// call the function and apply changes made on the opaque back to `self`.
    var s: some AsyncThrowingIteratorProtocol<Base.Element> = self
    defer { self = unsafeBitCast(s, to: Self.self) }
    return try! await s.next()
  }
}
extension AsyncPrefixSequence: AsyncSequenceOf {}
extension AsyncPrefixSequence: AsyncNonThrowingSequenceOf where Base: AsyncNonThrowingSequenceOf {}
