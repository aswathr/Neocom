//
//  NCFittingShipsViewController.swift
//  Neocom
//
//  Created by Artem Shimanski on 22.02.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

import UIKit
import CoreData

class NCLoadoutRow: TreeRow {
	let typeName: String
	let loadoutName: String
	let image: UIImage?
	let loadoutID: NSManagedObjectID
	init(loadout: NCLoadout, type: NCDBInvType) {
		typeName = type.typeName ?? ""
		loadoutName = loadout.name ?? ""
		image = type.icon?.image?.image
		loadoutID = loadout.objectID
		super.init(cellIdentifier: "NCDefaultTableViewCell")
	}
	
	override func configure(cell: UITableViewCell) {
		guard let cell = cell as? NCDefaultTableViewCell else {return}
		cell.titleLabel?.text = typeName
		cell.subtitleLabel?.text = loadoutName
		cell.iconView?.image = image
	}
	
	override var hashValue: Int {
		return loadoutID.hashValue
	}
	
	override func isEqual(_ object: Any?) -> Bool {
		return (object as? NCLoadoutRow)?.hashValue == hashValue
	}
	
	override func move(from: TreeNode) -> TreeNodeReloading {
		return .reconfigure
	}
}

class NCLoadoutsSection: TreeSection {
	let categoryID: NCDBDgmppItemCategoryID
	let filter: NSPredicate?
	private var observer: NSObjectProtocol?
	
	init(categoryID: NCDBDgmppItemCategoryID, filter: NSPredicate? = nil) {
		self.categoryID = categoryID
		self.filter = filter
		super.init()
		reload()
		
		observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: nil, queue: nil) { [weak self] note in
			if (note.object as? NSManagedObjectContext)?.persistentStoreCoordinator === NCStorage.sharedStorage?.persistentStoreCoordinator {
				self?.reload()
			}
		}
	}
	
	override var hashValue: Int {
		return categoryID.hashValue
	}
	
	override func isEqual(_ object: Any?) -> Bool {
		return (object as? NCLoadoutsSection)?.hashValue == hashValue
	}
	
	private func reload() {
		let categoryID = Int32(self.categoryID.rawValue)
		
		NCStorage.sharedStorage?.performBackgroundTask { managedObjectContext in
			let request = NSFetchRequest<NCLoadout>(entityName: "Loadout")
			request.predicate = self.filter
			guard let loadouts = try? managedObjectContext.fetch(request) else {return}
			var groups = [String: DefaultTreeSection]()
			
			var sections = [TreeNode]()
			
			NCDatabase.sharedDatabase?.performTaskAndWait { managedObjectContext in
				let invTypes = NCDBInvType.invTypes(managedObjectContext: managedObjectContext)
				for loadout in loadouts {
					guard let type = invTypes[Int(loadout.typeID)] else {continue}
					if type.dgmppItem?.groups?.first(where: {($0 as? NCDBDgmppItemGroup)?.category?.category == categoryID}) != nil {
						//guard let groupID = type.group?.groupID else {continue}
						guard let name = type.group?.groupName else {continue}
						let key = name
						let section = groups[key]
						let row = NCLoadoutRow(loadout: loadout, type: type)
						if let section = section {
							section.children?.append(row)
						}
						else {
							let section = DefaultTreeSection(cellIdentifier: "NCHeaderTableViewCell", nodeIdentifier: key, title: name.uppercased())
							section.children = [row]
							groups[key] = section
						}
					}
				}
			}
			
			for (_, group) in groups.sorted(by: { $0.key < $1.key}) {
				group.children = (group.children as? [NCLoadoutRow])?.sorted(by: { (a, b) -> Bool in
					return a.typeName == b.typeName ? a.loadoutName < b.loadoutName : a.typeName < b.typeName
				})
				sections.append(group)
			}
			
			DispatchQueue.main.async {
				self.children = sections
			}
		}
	}
}

class NCFittingShipsViewController: UITableViewController, TreeControllerDelegate {
	@IBOutlet var treeController: TreeController!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.estimatedRowHeight = tableView.rowHeight
		tableView.rowHeight = UITableViewAutomaticDimension
		treeController.delegate = self
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if treeController.rootNode == nil {
			self.treeController.rootNode = TreeNode()
			reload()
		}
	}
	
	// MARK: Navigation
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case "NCTypePickerViewController"?:
			guard let controller = segue.destination as? NCTypePickerViewController else {return}
			guard let categoryID = (sender as? NCTableViewCell)?.object as? NCDBDgmppItemCategoryID else {return}
			controller.category = NCDBDgmppItemCategory.category(categoryID: categoryID)
			controller.completionHandler = { [weak self] (type) in
				print ("\(type)")
				self?.dismiss(animated: true)
			}
		case "NCFittingEditorViewController"?:
			guard let controller = segue.destination as? NCFittingEditorViewController else {return}
			guard let (engine, fleet) = sender as? (NCFittingEngine, NCFittingFleet) else {return}
			controller.engine = engine
			controller.fleet = fleet
		default:
			break
		}
	}
	
	//MARK: - TreeControllerDelegate
	
	func treeController(_ treeController: TreeController, didSelectCellWithNode node: TreeNode) {

		if let node = node as? NCLoadoutRow {
			NCStorage.sharedStorage?.performBackgroundTask({ (managedObjectContext) in
				guard let loadout = (try? managedObjectContext.existingObject(with: node.loadoutID)) as? NCLoadout else {return}
				let engine = NCFittingEngine()
				engine.performBlockAndWait {
					let fleet = NCFittingFleet(loadouts: [loadout], engine: engine)
					DispatchQueue.main.async {
						Router.Fitting.Editor(fleet: fleet, engine: engine).perform(source: self)
					}
				}
			})
		}
		else if let route = (node as? TreeRow)?.route {
			route.perform(source: self, view: treeController.cell(for: node))
		}
	}
	
	func treeController(_ treeController: TreeController, editActionsForNode node: TreeNode) -> [UITableViewRowAction]? {
		guard let node = node as? NCLoadoutRow else {return nil}
		
		let deleteAction = UITableViewRowAction(style: .destructive, title: NSLocalizedString("Delete", comment: "")) { _ in
			guard let context = NCStorage.sharedStorage?.viewContext else {return}
			guard let loadout = (try? context.existingObject(with: node.loadoutID)) as? NCLoadout else {return}
			context.delete(loadout)
			if context.hasChanges {
				try? context.save()
			}
		}
		
		return [deleteAction]
	}
	
	// MARK: NCTreeControllerDelegate
	
	func treeController(_ treeController: NCTreeController, cellIdentifierForItem item: AnyObject) -> String {
		return (item as! NCTreeNode).cellIdentifier
	}
	
	func treeController(_ treeController: NCTreeController, configureCell cell: UITableViewCell, withItem item: AnyObject) {
		(item as! NCTreeNode).configure(cell: cell)
	}
	
	func treeController(_ treeController: NCTreeController, isItemExpandable item: AnyObject) -> Bool {
		return (item as! NCTreeNode).canExpand
	}
	
	func treeController(_ treeController: NCTreeController, didSelectCell cell: UITableViewCell, withItem item: AnyObject) -> Void {
		guard let row = item as? NCDefaultTreeRow else {return}
		if let segue = row.segue {
			guard let controller = storyboard?.instantiateViewController(withIdentifier: "NCTypePickerViewController") as? NCTypePickerViewController else {return}
			controller.category = NCDBDgmppItemCategory.category(categoryID: row.object as! NCDBDgmppItemCategoryID)
			controller.completionHandler = { [weak self] (_, type) in
				guard let strongSelf = self else {return}
				strongSelf.dismiss(animated: true)
				
				let engine = NCFittingEngine()
				let typeID = Int(type.typeID)
				engine.perform {
					let fleet = NCFittingFleet(typeID: typeID, engine: engine)
					DispatchQueue.main.async {
						Router.Fitting.Editor(fleet: fleet, engine: engine).perform(source: strongSelf, view: cell)
					}
				}
			}
			self.present(controller, animated: true, completion: nil)
			//self.performSegue(withIdentifier: segue, sender: cell)
		}
	}
	
	func treeController(_ treeController: NCTreeController, canEditChild child: Int, ofItem item: AnyObject?) -> Bool {
		return true
	}
	
	//MARK: - Private
	
	private func reload() {
		var sections = [TreeNode]()
	
		
		sections.append(NCActionRow(cellIdentifier: "NCDefaultTableViewCell", image: #imageLiteral(resourceName: "fitting"), title: NSLocalizedString("New Ship Fit", comment: ""), accessoryType: .disclosureIndicator, route: Router.Database.TypePicker(category: NCDBDgmppItemCategory.category(categoryID: .ship)!, completionHandler: {[weak self] (controller, type) in
			guard let strongSelf = self else {return}
			strongSelf.dismiss(animated: true)
			
			let engine = NCFittingEngine()
			let typeID = Int(type.typeID)
			engine.perform {
				let fleet = NCFittingFleet(typeID: typeID, engine: engine)
				DispatchQueue.main.async {
					Router.Fitting.Editor(fleet: fleet, engine: engine).perform(source: strongSelf)
				}
			}

		})))
		
		sections.append(NCActionRow(cellIdentifier: "NCDefaultTableViewCell", image: #imageLiteral(resourceName: "browser"), title: NSLocalizedString("Import/Export", comment: ""), accessoryType: .disclosureIndicator))
		sections.append(NCActionRow(cellIdentifier: "NCDefaultTableViewCell", image: #imageLiteral(resourceName: "eveOnlineLogin"), title: NSLocalizedString("Browse Ingame Fits", comment: ""), accessoryType: .disclosureIndicator))
		
		sections.append(NCLoadoutsSection(categoryID: .ship))
		self.treeController.rootNode?.children = sections
	}
}
