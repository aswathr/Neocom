//
//  Router.swift
//  Neocom
//
//  Created by Artem Shimanski on 20.02.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

import UIKit
import CoreData

enum RouteKind {
	case push
	case modal
	case adaptive
	case sheet
}

class Route: Hashable {
	let kind: RouteKind
	let identifier: String?
	let storyboard: UIStoryboard?
	let viewController: UIViewController?
	
	init(kind: RouteKind, storyboard: UIStoryboard? = nil,  identifier: String? = nil, viewController: UIViewController? = nil) {
		self.kind = kind
		self.storyboard = storyboard
		self.identifier = identifier
		self.viewController = viewController
	}
	
	func perform(source: UIViewController, view: UIView? = nil) {
		let destination: UIViewController! = viewController ?? (storyboard ?? UIStoryboard(name: "Main", bundle: nil))?.instantiateViewController(withIdentifier: identifier!)
		prepareForSegue(source: source, destination: destination)
		
		switch kind {
		case .push:
			if source.parent is UISearchController {
				source.presentingViewController?.navigationController?.pushViewController(destination, animated: true)
			}
			else {
				((source as? UINavigationController) ?? source.navigationController)?.pushViewController(destination, animated: true)
			}
		case .modal:
			source.present(destination, animated: true, completion: nil)
			
		case .adaptive:
			if source.presentationController is NCSheetPresentationController || source.navigationController?.presentationController is NCSheetPresentationController {
				let destination = destination as? UINavigationController ?? NCNavigationController(rootViewController: destination)
				source.present(destination, animated: true, completion: nil)
				destination.topViewController?.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Close", comment: ""), style: .plain, target: destination, action: #selector(UIViewController.dismissAnimated(_:)))
			}
			else if let navigationController = source.navigationController {
				navigationController.pushViewController(destination, animated: true)
			}
			
		case .sheet:
			let destination = destination as? UINavigationController ?? NCNavigationController(rootViewController: destination)
			let presentationController = NCSheetPresentationController(presentedViewController: destination, presenting: source)
			withExtendedLifetime(presentationController) {
				destination.transitioningDelegate = presentationController
				source.present(destination, animated: true, completion: nil)
			}
		}
		
	}
	
	func prepareForSegue(source: UIViewController, destination: UIViewController) {
	}
	
	var hashValue: Int {
		return kind.hashValue ^ (viewController?.hashValue ?? ((identifier?.hashValue ?? 0) ^ (storyboard?.hashValue ?? 0)))
	}
	
	static func == (lhs: Route, rhs: Route) -> Bool {
		return lhs.kind == rhs.kind && lhs.identifier == rhs.identifier && lhs.storyboard == rhs.storyboard && lhs.viewController == rhs.viewController
	}
}

struct Router {
	
	struct Database {
		
		class TypeInfo: Route {
			let type: NCDBInvType?
			let typeID: Int?
			let objectID: NSManagedObjectID?
			
			private init(type: NCDBInvType?, typeID: Int?, objectID: NSManagedObjectID?, kind: RouteKind) {
				self.type = type
				self.typeID = typeID
				self.objectID = objectID
				super.init(kind: kind, identifier: "NCDatabaseTypeInfoViewController")
			}
			
			convenience init(_ type: NCDBInvType, kind: RouteKind = .adaptive) {
				self.init(type: type, typeID: nil, objectID: nil, kind: kind)
			}
			
			convenience init(_ typeID: Int, kind: RouteKind = .adaptive) {
				self.init(type: nil, typeID: typeID, objectID: nil, kind: kind)
			}
			
			convenience init(_ objectID: NSManagedObjectID, kind: RouteKind = .adaptive) {
				self.init(type: nil, typeID: nil, objectID: objectID, kind: kind)
			}
			
			override func prepareForSegue(source: UIViewController, destination: UIViewController) {
				let destination = destination as! NCDatabaseTypeInfoViewController
				if let type = type {
					destination.type = type
				}
				else if let typeID = typeID {
					destination.type = NCDatabase.sharedDatabase?.invTypes[typeID]
				}
				else if let objectID = objectID {
					destination.type = (try? NCDatabase.sharedDatabase?.viewContext.existingObject(with: objectID)) as? NCDBInvType
				}
			}
		}
	}
	
	struct Fitting {
		
		class Editor: Route {
			let fleet: NCFittingFleet
			let engine: NCFittingEngine
			
			init(fleet: NCFittingFleet, engine: NCFittingEngine) {
				self.fleet = fleet
				self.engine = engine
				super.init(kind: .push, identifier: "NCShipFittingViewController")
			}
			
			override func prepareForSegue(source: UIViewController, destination: UIViewController) {
				let destination = destination as! NCShipFittingViewController
				destination.fleet = fleet
				destination.engine = engine
			}
		}
		
		class Ammo: Route {
			let category: NCDBDgmppItemCategory
			let completionHandler: (NCFittingAmmoViewController, NCDBInvType) -> Void
			
			init(category: NCDBDgmppItemCategory, completionHandler: @escaping (NCFittingAmmoViewController, NCDBInvType) -> Void) {
				self.category = category
				self.completionHandler = completionHandler
				super.init(kind: .adaptive, identifier: "NCFittingAmmoViewController")
			}
			
			override func prepareForSegue(source: UIViewController, destination: UIViewController) {
				let destination = destination as! NCFittingAmmoViewController
				destination.category = category
				destination.completionHandler = completionHandler
			}
		}

		
		class AreaEffects: Route {
			let completionHandler: (NCFittingAreaEffectsViewController, NCDBInvType) -> Void
			
			init(completionHandler: @escaping (NCFittingAreaEffectsViewController, NCDBInvType) -> Void) {
				self.completionHandler = completionHandler
				super.init(kind: .adaptive, identifier: "NCFittingAreaEffectsViewController")
			}
			
			override func prepareForSegue(source: UIViewController, destination: UIViewController) {
				(destination as! NCFittingAreaEffectsViewController).completionHandler = completionHandler
			}
		}
		
		class DamagePatterns: Route {
			let completionHandler: (NCFittingDamagePatternsViewController, NCFittingDamage) -> Void
			
			init(completionHandler: @escaping (NCFittingDamagePatternsViewController, NCFittingDamage) -> Void) {
				self.completionHandler = completionHandler
				super.init(kind: .adaptive, identifier: "NCFittingDamagePatternsViewController")
			}
			
			override func prepareForSegue(source: UIViewController, destination: UIViewController) {
				(destination as! NCFittingDamagePatternsViewController).completionHandler = completionHandler
			}
		}
		
		class Variations: Route {
			let type: NCDBInvType
			let completionHandler: (NCFittingVariationsViewController, NCDBInvType) -> Void
			
			init(type: NCDBInvType, completionHandler: @escaping (NCFittingVariationsViewController, NCDBInvType) -> Void) {
				self.type = type
				self.completionHandler = completionHandler
				super.init(kind: .adaptive, identifier: "NCFittingVariationsViewController")
			}
			
			override func prepareForSegue(source: UIViewController, destination: UIViewController) {
				let destination = destination as! NCFittingVariationsViewController
				destination.type = type
				destination.completionHandler = completionHandler
			}
		}

		class ModuleActions: Route {
			let modules: [NCFittingModule]
			
			init(_ modules: [NCFittingModule]) {
				self.modules = modules
				super.init(kind: .sheet, identifier: "NCFittingModuleActionsViewController")
			}
			
			override func prepareForSegue(source: UIViewController, destination: UIViewController) {
				(destination as! NCFittingModuleActionsViewController).modules = modules
			}
		}
		
		class DroneActions: Route {
			let drones: [NCFittingDrone]
			
			init(_ drones: [NCFittingDrone]) {
				self.drones = drones
				super.init(kind: .sheet, identifier: "NCFittingDroneActionsViewController")
			}
			
			override func prepareForSegue(source: UIViewController, destination: UIViewController) {
				(destination as! NCFittingDroneActionsViewController).drones = drones
			}
		}

	}
}
