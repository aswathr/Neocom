//
//  CachedValue.swift
//  Neocom
//
//  Created by Artem Shimanski on 24.08.2018.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import Foundation
import CloudData
import CoreData

protocol CachedValueProtocol {
	associatedtype Value
	var value: Value {get}
	var cachedUntil: Date? {get}
	var observer: APIObserver<Value>? {get}
}

class CachedValue<Value>: CachedValueProtocol {
	var value: Value
	var cachedUntil: Date?
	let observer: APIObserver<Value>?
	
	init(value: Value, cachedUntil: Date?, observer: APIObserver<Value>?) {
		self.value = value
		self.cachedUntil = cachedUntil
		self.observer = observer
		observer?.cachedValue = self
	}
	
	func map<T>(_ transform: @escaping (Value) throws -> T ) rethrows -> CachedValue<T> {
		return try CachedValue<T>(value: transform(value), cachedUntil: cachedUntil, observer: observer?.map(transform))
	}
}

class APIObserver<Value> {
	
	var handler: ((CachedValue<Value>) -> Void)?
	weak var cachedValue: CachedValue<Value>?
	
	func map<T>(_ transform: @escaping (Value) throws -> T ) -> APIObserver<T> {
		return APIObserverMap<T, Value>(self, transform: transform)
	}
	
	func notify(newValue: Value, cachedUntil: Date?) {
		if let handler = handler, let cachedValue = cachedValue {
			cachedValue.value = newValue
			cachedValue.cachedUntil = cachedUntil
			handler(cachedValue)
		}
	}
}

class APICacheRecordObserver<Value: Codable>: APIObserver<Value> {
	let recordID: NSManagedObjectID?
	let dataID: NSManagedObjectID?
	let cache: Cache
	
	init(cacheRecord: CacheRecord, cache: Cache) {
		self.cache = cache
		recordID = cacheRecord.objectID
		dataID = cacheRecord.data?.objectID
	}
	
	override var handler: ((CachedValue<Value>) -> Void)? {
		didSet {
			if observer == nil {
				observer = NotificationCenter.default.addNotificationObserver(forName: .NSManagedObjectContextDidSave, object: nil, queue: nil, using: { [weak self] note in
					self?.didSave(note)
				})
			}
		}
	}
	
	private var observer: NotificationObserver?
	
	private func didSave(_ note: Notification) {
		guard let objectIDs = (note.userInfo?[NSUpdatedObjectsKey] as? NSSet)?.compactMap ({ ($0 as? NSManagedObject)?.objectID ?? $0 as? NSManagedObjectID }) else {return}
		guard !Set(objectIDs).intersection([recordID, dataID].compactMap{$0}).isEmpty else {return}
		cache.performBackgroundTask { context -> Void in
			guard let recordID = self.recordID else {return}
			guard let record: CacheRecord = (try? context.existingObject(with: recordID)) ?? nil else {return}
			guard let value: Value = record.getValue() else {return}
			self.notify(newValue: value, cachedUntil: record.cachedUntil)
		}
	}
}

class APIObserverMap<Value, Base>: APIObserver<Value> {
	let base: APIObserver<Base>
	let transform: (Base) throws -> Value
	
	override var handler: ((CachedValue<Value>) -> Void)? {
		didSet {
			if handler == nil {
				base.handler = nil
			}
			else {
				base.handler = { [weak self] newValue in
					guard let strongSelf = self else {return}
					try? strongSelf.notify(newValue: strongSelf.transform(newValue.value), cachedUntil: newValue.cachedUntil)
				}
			}
		}
	}
	
	init(_ base: APIObserver<Base>, transform: @escaping (Base) throws -> Value ) {
		self.base = base
		self.transform = transform
		super.init()
	}
}

func all<R, A, B>(_ a: CachedValue<A>, _ b: CachedValue<B>) -> Join2<R, A, B> {
	return Join2(a: a, b: b)
}

func all<R, A, B, C>(_ a: CachedValue<A>, _ b: CachedValue<B>, _ c: CachedValue<C>) -> Join3<R, A, B, C> {
	return Join3(a: a, b: b, c: c)
}

func all<R, A, B, C, D>(_ a: CachedValue<A>, _ b: CachedValue<B>, _ c: CachedValue<C>, _ d: CachedValue<D>) -> Join4<R, A, B, C, D> {
	return Join4(a: a, b: b, c: c, d: d)
}

func all<R, A, B, C, D, E>(_ a: CachedValue<A>, _ b: CachedValue<B>, _ c: CachedValue<C>, _ d: CachedValue<D>, _ e: CachedValue<E>) -> Join5<R, A, B, C, D, E> {
	return Join5(a: a, b: b, c: c, d: d, e: e)
}

func all<R, A, B, C, D, E, F>(_ a: CachedValue<A>, _ b: CachedValue<B>, _ c: CachedValue<C>, _ d: CachedValue<D>, _ e: CachedValue<E>, _ f: CachedValue<F>) -> Join6<R, A, B, C, D, E, F> {
	return Join6(a: a, b: b, c: c, d: d, e: e, f: f)
}

func all<R, A, B>(_ values: (CachedValue<A>, CachedValue<B>)) -> Join2<R, A, B> {
	return Join2(a: values.0, b: values.1)
}

func all<R, A, B, C>(_ values: (CachedValue<A>, CachedValue<B>, CachedValue<C>)) -> Join3<R, A, B, C> {
	return Join3(a: values.0, b: values.1, c: values.2)
}

func all<R, A, B, C, D>(_ values: (CachedValue<A>, CachedValue<B>, CachedValue<C>, CachedValue<D>)) -> Join4<R, A, B, C, D> {
	return Join4(a: values.0, b: values.1, c: values.2, d: values.3)
}

func all<R, A, B, C, D, E>(_ values: (CachedValue<A>, CachedValue<B>, CachedValue<C>, CachedValue<D>, CachedValue<E>)) -> Join5<R, A, B, C, D, E> {
	return Join5(a: values.0, b: values.1, c: values.2, d: values.3, e: values.4)
}

func all<R, A, B, C, D, E, F>(_ values: (CachedValue<A>, CachedValue<B>, CachedValue<C>, CachedValue<D>, CachedValue<E>, CachedValue<F>)) -> Join6<R, A, B, C, D, E, F> {
	return Join6(a: values.0, b: values.1, c: values.2, d: values.3, e: values.4, f: values.5)
}


struct Join2<R, A, B> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	
	func map(_ transform: @escaping (A, B) -> R) -> CachedValue<R> {
		let cachedUntil = [a.cachedUntil, b.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value)
		let observer = APIObserverJoin2(a, b, transform: transform)
		return CachedValue(value: value, cachedUntil: cachedUntil, observer: observer)
	}
}

struct Join3<R, A, B, C> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	var c: CachedValue<C>
	
	func map(_ transform: @escaping (A, B, C) -> R) -> CachedValue<R> {
		let cachedUntil = [a.cachedUntil, b.cachedUntil, c.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value, c.value)
		let observer = APIObserverJoin3(a, b, c, transform: transform)
		return CachedValue(value: value, cachedUntil: cachedUntil, observer: observer)
	}
}

struct Join4<R, A, B, C, D> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	var c: CachedValue<C>
	var d: CachedValue<D>
	
	func map(_ transform: @escaping (A, B, C, D) -> R) -> CachedValue<R> {
		let cachedUntil = [a.cachedUntil, b.cachedUntil, c.cachedUntil, d.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value, c.value, d.value)
		let observer = APIObserverJoin4(a, b, c, d, transform: transform)
		return CachedValue(value: value, cachedUntil: cachedUntil, observer: observer)
	}
}

struct Join5<R, A, B, C, D, E> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	var c: CachedValue<C>
	var d: CachedValue<D>
	var e: CachedValue<E>
	
	func map(_ transform: @escaping (A, B, C, D, E) -> R) -> CachedValue<R> {
		let cachedUntil = [a.cachedUntil, b.cachedUntil, c.cachedUntil, d.cachedUntil, e.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value, c.value, d.value, e.value)
		let observer = APIObserverJoin5(a, b, c, d, e, transform: transform)
		return CachedValue(value: value, cachedUntil: cachedUntil, observer: observer)
	}
}

struct Join6<R, A, B, C, D, E, F> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	var c: CachedValue<C>
	var d: CachedValue<D>
	var e: CachedValue<E>
	var f: CachedValue<F>
	
	func map(_ transform: @escaping (A, B, C, D, E, F) -> R) -> CachedValue<R> {
		let cachedUntil = [a.cachedUntil, b.cachedUntil, c.cachedUntil, d.cachedUntil, e.cachedUntil, f.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value, c.value, d.value, e.value, f.value)
		let observer = APIObserverJoin6(a, b, c, d, e, f, transform: transform)
		return CachedValue(value: value, cachedUntil: cachedUntil, observer: observer)
	}
}

class APIObserverJoin2<Value, A, B>: APIObserver<Value> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	let transform: (A, B) -> Value
	
	override var handler: ((CachedValue<Value>) -> Void)? {
		didSet {
			if handler == nil {
				a.observer?.handler = nil
				b.observer?.handler = nil
			}
			else {
				a.observer?.handler = { [weak self] newValue in
					self?.a = newValue
					self?.notify()
				}
				
				b.observer?.handler = { [weak self] newValue in
					self?.b = newValue
					self?.notify()
				}
			}
		}
	}
	
	private func notify() {
		let cachedUntil = [a.cachedUntil, b.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value)
		notify(newValue: value, cachedUntil: cachedUntil)
	}
	
	init(_ a: CachedValue<A>, _ b: CachedValue<B>, transform: @escaping (A, B) -> Value ) {
		self.a = a
		self.b = b
		self.transform = transform
	}
}

class APIObserverJoin3<Value, A, B, C>: APIObserver<Value> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	var c: CachedValue<C>
	let transform: (A, B, C) -> Value
	
	override var handler: ((CachedValue<Value>) -> Void)? {
		didSet {
			if handler == nil {
				a.observer?.handler = nil
				b.observer?.handler = nil
				c.observer?.handler = nil
			}
			else {
				a.observer?.handler = { [weak self] newValue in
					self?.a = newValue
					self?.notify()
				}
				
				b.observer?.handler = { [weak self] newValue in
					self?.b = newValue
					self?.notify()
				}
				
				c.observer?.handler = { [weak self] newValue in
					self?.c = newValue
					self?.notify()
				}

			}
		}
	}
	
	private func notify() {
		let cachedUntil = [a.cachedUntil, b.cachedUntil, c.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value, c.value)
		notify(newValue: value, cachedUntil: cachedUntil)
	}
	
	init(_ a: CachedValue<A>, _ b: CachedValue<B>, _ c: CachedValue<C>, transform: @escaping (A, B, C) -> Value ) {
		self.a = a
		self.b = b
		self.c = c
		self.transform = transform
	}
}

class APIObserverJoin4<Value, A, B, C, D>: APIObserver<Value> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	var c: CachedValue<C>
	var d: CachedValue<D>
	let transform: (A, B, C, D) -> Value
	
	override var handler: ((CachedValue<Value>) -> Void)? {
		didSet {
			if handler == nil {
				a.observer?.handler = nil
				b.observer?.handler = nil
				c.observer?.handler = nil
				d.observer?.handler = nil
			}
			else {
				a.observer?.handler = { [weak self] newValue in
					self?.a = newValue
					self?.notify()
				}
				
				b.observer?.handler = { [weak self] newValue in
					self?.b = newValue
					self?.notify()
				}
				
				c.observer?.handler = { [weak self] newValue in
					self?.c = newValue
					self?.notify()
				}

				d.observer?.handler = { [weak self] newValue in
					self?.d = newValue
					self?.notify()
				}

			}
		}
	}
	
	private func notify() {
		let cachedUntil = [a.cachedUntil, b.cachedUntil, c.cachedUntil, d.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value, c.value, d.value)
		notify(newValue: value, cachedUntil: cachedUntil)
	}
	
	init(_ a: CachedValue<A>, _ b: CachedValue<B>, _ c: CachedValue<C>, _ d: CachedValue<D>, transform: @escaping (A, B, C, D) -> Value ) {
		self.a = a
		self.b = b
		self.c = c
		self.d = d
		self.transform = transform
	}
}

class APIObserverJoin5<Value, A, B, C, D, E>: APIObserver<Value> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	var c: CachedValue<C>
	var d: CachedValue<D>
	var e: CachedValue<E>
	let transform: (A, B, C, D, E) -> Value
	
	override var handler: ((CachedValue<Value>) -> Void)? {
		didSet {
			if handler == nil {
				a.observer?.handler = nil
				b.observer?.handler = nil
				c.observer?.handler = nil
				d.observer?.handler = nil
				e.observer?.handler = nil
			}
			else {
				a.observer?.handler = { [weak self] newValue in
					self?.a = newValue
					self?.notify()
				}
				
				b.observer?.handler = { [weak self] newValue in
					self?.b = newValue
					self?.notify()
				}
				
				c.observer?.handler = { [weak self] newValue in
					self?.c = newValue
					self?.notify()
				}
				
				d.observer?.handler = { [weak self] newValue in
					self?.d = newValue
					self?.notify()
				}

				e.observer?.handler = { [weak self] newValue in
					self?.e = newValue
					self?.notify()
				}

			}
		}
	}
	
	private func notify() {
		let cachedUntil = [a.cachedUntil, b.cachedUntil, c.cachedUntil, d.cachedUntil, e.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value, c.value, d.value, e.value)
		notify(newValue: value, cachedUntil: cachedUntil)
	}
	
	init(_ a: CachedValue<A>, _ b: CachedValue<B>, _ c: CachedValue<C>, _ d: CachedValue<D>, _ e: CachedValue<E>, transform: @escaping (A, B, C, D, E) -> Value ) {
		self.a = a
		self.b = b
		self.c = c
		self.d = d
		self.e = e
		self.transform = transform
	}
}

class APIObserverJoin6<Value, A, B, C, D, E, F>: APIObserver<Value> {
	var a: CachedValue<A>
	var b: CachedValue<B>
	var c: CachedValue<C>
	var d: CachedValue<D>
	var e: CachedValue<E>
	var f: CachedValue<F>
	let transform: (A, B, C, D, E, F) -> Value
	
	override var handler: ((CachedValue<Value>) -> Void)? {
		didSet {
			if handler == nil {
				a.observer?.handler = nil
				b.observer?.handler = nil
				c.observer?.handler = nil
				d.observer?.handler = nil
				e.observer?.handler = nil
				f.observer?.handler = nil
			}
			else {
				a.observer?.handler = { [weak self] newValue in
					self?.a = newValue
					self?.notify()
				}
				
				b.observer?.handler = { [weak self] newValue in
					self?.b = newValue
					self?.notify()
				}
				
				c.observer?.handler = { [weak self] newValue in
					self?.c = newValue
					self?.notify()
				}
				
				d.observer?.handler = { [weak self] newValue in
					self?.d = newValue
					self?.notify()
				}
				
				e.observer?.handler = { [weak self] newValue in
					self?.e = newValue
					self?.notify()
				}

				f.observer?.handler = { [weak self] newValue in
					self?.f = newValue
					self?.notify()
				}

			}
		}
	}
	
	private func notify() {
		let cachedUntil = [a.cachedUntil, b.cachedUntil, c.cachedUntil, d.cachedUntil, e.cachedUntil, f.cachedUntil].compactMap{$0}.min()
		let value = transform(a.value, b.value, c.value, d.value, e.value, f.value)
		notify(newValue: value, cachedUntil: cachedUntil)
	}
	
	init(_ a: CachedValue<A>, _ b: CachedValue<B>, _ c: CachedValue<C>, _ d: CachedValue<D>, _ e: CachedValue<E>, _ f: CachedValue<F>, transform: @escaping (A, B, C, D, E, F) -> Value ) {
		self.a = a
		self.b = b
		self.c = c
		self.d = d
		self.e = e
		self.f = f
		self.transform = transform
	}
}