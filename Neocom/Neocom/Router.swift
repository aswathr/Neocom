//
//  Router.swift
//  Neocom
//
//  Created by Artem Shimanski on 03.09.2018.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import Foundation
import Futures

enum RouteKind {
	case push
	case modal
	case adaptivePush
	case adaptiveModal
	case sheet
	case popover
	case detail
	case embed(container: UIView)
}

struct Route<Assembly: Neocom.Assembly> {
	var assembly: Assembly
	var input: Assembly.View.Input
	
	init(assembly: Assembly, input: Assembly.View.Input) {
		self.assembly = assembly
		self.input = input
	}


	@discardableResult
	func perform<T: View>(from view: T, sender: Any? = nil, kind: RouteKind?) -> Future<Bool> where T: UIViewController, Assembly.View: UIViewController {
		return assembly.instantiate(input).then(on: .main) { destination -> Future<Bool> in
			guard let kind = kind else {return .init(false)}
			let promise = Promise<Bool>()
			destination.unwinder = ViewControllerUnwinder(kind: kind, source: view)
			
			switch kind {
			case .push:
				let navigationController = view.parent is UISearchController ?
					view.presentingViewController?.navigationController :
					((view as? UINavigationController) ?? view.navigationController)

				if let navigationController = navigationController {
					let delegate = NavigationControllerDelegate(navigationController)
					delegate.handler = {
						delegate.invalidate()
						try! promise.fulfill(true)
					}
					navigationController.pushViewController(destination, animated: true)
				}
				else {
					try! promise.fulfill(false)
				}
			case .modal:
				destination.modalPresentationStyle = .pageSheet
				view.present(destination, animated: true) {
					try! promise.fulfill(true)
				}
			default:
				try! promise.fulfill(false)
			}
			
			
			return promise.future
		}
	}
}

extension Route  where Assembly.View.Input == Void {
	init(assembly: Assembly) {
		self.assembly = assembly
	}

}

protocol Unwinder {
	var kind: RouteKind {get}
	var previous: Unwinder? {get}
	func unwind() -> Future<Bool>
	func unwind<T: View>(to view: T) -> Future<Bool>
	func canPerformUnwind<T: View>(to view: T) -> Bool
}

fileprivate struct ViewControllerUnwinder<Source: View>: Unwinder where Source: UIViewController {
	var kind: RouteKind
	var previous: Unwinder? {
		return source?.unwinder
	}
	
	weak var source: Source?
	
	func unwind() -> Future<Bool> {
		guard let source = source else {return .init(false)}

		
		switch kind {
		case .push, .adaptivePush:
			let promise = Promise<Bool>()
			
			let presented = sequence(first: source, next: {$0.parent}).first(where: {$0.presentedViewController != nil})
			if let presented = presented {
				presented.dismiss(animated: true) {
					try! promise.fulfill(true)
				}
				source.navigationController?.popToViewController(source, animated: true)
			}
			else if let navigationController = source.navigationController, navigationController.popToViewController(source, animated: true)?.isEmpty == false {
				
				let delegate = NavigationControllerDelegate(navigationController)
				delegate.handler = {
					delegate.invalidate()
					try! promise.fulfill(true)
				}
			}
			else {
				try! promise.fulfill(false)
			}
			return promise.future
		case .modal, .adaptiveModal, .sheet, .popover:
			let presented = sequence(first: source, next: {$0.parent}).first(where: {$0.presentedViewController != nil})
			if let presented = presented {
				let promise = Promise<Bool>()
				presented.dismiss(animated: true) {
					try! promise.fulfill(true)
				}
				return promise.future
			}
			else {
				return .init(false)
			}
		default:
			return .init(false)
		}
	}
	
	func unwind<T: View>(to view: T) -> Future<Bool> {
		return sequence(first: self as Unwinder, next: {$0.previous}).first(where: {$0.canPerformUnwind(to: view)})?.unwind() ?? .init(false)
	}
	
	func canPerformUnwind<T: View>(to view: T) -> Bool {
		return (view as? Source) === source
	}
	
}

enum Router {
	enum MainMenu {
	}
}

class NavigationControllerDelegate: NSObject, UINavigationControllerDelegate {
	var handler: (() -> Void)?
	var oldDelegate: UINavigationControllerDelegate?
	weak var navigationController: UINavigationController?
	
	init(_ navigationController: UINavigationController) {
		self.navigationController = navigationController
		oldDelegate = navigationController.delegate
		super.init()
		navigationController.delegate = self
	}
	
	func invalidate() {
		navigationController?.delegate = oldDelegate
	}
	
	deinit {
		if navigationController?.delegate === self {
			navigationController?.delegate = oldDelegate
		}
	}
	
	func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
		oldDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
	}
	
	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		oldDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
		
		DispatchQueue.main.async {
			self.handler?()
		}
	}
	
	override func responds(to aSelector: Selector!) -> Bool {
		return oldDelegate?.responds(to: aSelector) ?? (aSelector == #selector(navigationController(_:didShow:animated:)))
	}
	
	func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
		assert(oldDelegate?.navigationControllerSupportedInterfaceOrientations != nil)
		return oldDelegate?.navigationControllerSupportedInterfaceOrientations?(navigationController) ?? []
	}
	
	func navigationControllerPreferredInterfaceOrientationForPresentation(_ navigationController: UINavigationController) -> UIInterfaceOrientation {
		assert(oldDelegate?.navigationControllerPreferredInterfaceOrientationForPresentation != nil)
		return oldDelegate?.navigationControllerPreferredInterfaceOrientationForPresentation?(navigationController) ?? .portrait
	}
	
	
	func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
		return oldDelegate?.navigationController?(navigationController, interactionControllerFor: animationController)
	}
	
	
	func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		return oldDelegate?.navigationController?(navigationController, animationControllerFor: operation, from: fromVC, to: toVC)
	}
}
