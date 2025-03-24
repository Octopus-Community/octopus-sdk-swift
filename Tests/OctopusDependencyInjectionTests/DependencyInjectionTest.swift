//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Testing
import Combine
import OctopusDependencyInjection

struct DependencyInjectionTest {

    enum Injected {
        static let classA = Injector.InjectedIdentifier<ClassA>()
        static let proto = Injector.InjectedIdentifier<any Proto>()
        static let dependentClass = Injector.InjectedIdentifier<DependentClass>()
    }

    class ClassA: InjectableObject {
        static let injectedIdentifier = Injected.classA

        init(initIsCalled: CurrentValueSubject<Bool, Never>) {
            initIsCalled.send(true)
        }
    }

    protocol Proto: InjectableObject {
        func aFunc() -> String
    }

    class ClassB: Proto {
        static let injectedIdentifier = Injected.proto

        func aFunc() -> String {
            return "classB"
        }
    }

    class ClassC: Proto {
        static let injectedIdentifier = Injected.proto

        func aFunc() -> String {
            return "classC"
        }
    }

    class DependentClass: InjectableObject {
        static let injectedIdentifier = Injected.dependentClass

        let classA: ClassA
        let proto: any Proto

        init(injector: Injector) {
            self.classA = injector.getInjected(identifiedBy: Injected.classA)
            self.proto = injector.getInjected(identifiedBy: Injected.proto)
        }
    }

    @Test func initCalledOnlyWhenNeeded() {
        let initIsCalled = CurrentValueSubject<Bool, Never>(false)

        let injector = Injector()
        injector.register { _ in ClassA(initIsCalled: initIsCalled) }

        // Registering should not call the init immediatly
        #expect(!initIsCalled.value)

        _ = injector.getInjected(identifiedBy: Injected.classA)
        #expect(initIsCalled.value)
    }

    @Test func checkDependencyBetweenInjectedObjects() {
        let initIsCalled = CurrentValueSubject<Bool, Never>(false)

        let injector = Injector()
        injector.register { _ in ClassA(initIsCalled: initIsCalled) }
        injector.register { _ in ClassC() }
        injector.register { DependentClass(injector: $0) }

        let dependentClass = injector.getInjected(identifiedBy: Injected.dependentClass)
        #expect(initIsCalled.value)
        #expect(dependentClass.proto is ClassC)
    }

    @Test func getCorrectClass() {
        let injector = Injector()
        injector.register { _ in ClassB() }

        let aProto = injector.getInjected(identifiedBy: Injected.proto)
        #expect(aProto is ClassB)
    }

}
