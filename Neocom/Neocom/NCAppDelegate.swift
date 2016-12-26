//
//  NCAppDelegate.swift
//  Neocom
//
//  Created by Artem Shimanski on 30.11.16.
//  Copyright © 2016 Artem Shimanski. All rights reserved.
//

import UIKit
import EVEAPI
import CoreData

@UIApplicationMain
class NCAppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:
		[UIApplicationLaunchOptionsKey: Any]?) -> Bool {
//		let directory = URL.init(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]).appendingPathComponent("com.shimanski.eveuniverse.NCCache")
//		let url = directory.appendingPathComponent("store.sqlite")
//		try? FileManager.default.removeItem(at: url)

		
		setupAppearance()
		
		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}
	
	func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
		
		if OAuth2Handler.handleOpenURL(url, clientID: ESClientID, secretKey: ESSecretKey, completionHandler: { (result) in
			switch result {
			case let .success(token):
				NCStorage.sharedStorage?.performBackgroundTask({ (managedObjectContext) in
					let account = NCAccount(entity: NSEntityDescription.entity(forEntityName: "Account", in: managedObjectContext)!, insertInto: managedObjectContext)
					account.token = token
					account.uuid = UUID().uuidString
					DispatchQueue.main.async {
						guard let context = NCStorage.sharedStorage?.viewContext else {return}
						let request = NSFetchRequest<NCAccount>(entityName: "Account")
						guard let result = try? context.fetch(request), result.count == 1 else {return}
						NCAccount.current = result.first
					}
				})
				
				break
			case let .failure(error):
				break
			}
		}) {
			return true
		}
		else {
			return false
		}
	}
	
	//MARK: Private

	private func setupAppearance() {
		CSScheme.currentScheme = CSScheme.Dark
		let navigationBar = UINavigationBar.appearance(whenContainedInInstancesOf: [NCNavigationController.self])
		navigationBar.setBackgroundImage(UIImage.image(color: UIColor.background), for: UIBarMetrics.default)
		navigationBar.shadowImage = UIImage.image(color: UIColor.background)
		navigationBar.barTintColor = UIColor.background
		let tableView = NCTableView.appearance()
		tableView.tableBackgroundColor = UIColor.background
		tableView.separatorColor = UIColor.separator
		NCTableViewCell.appearance().backgroundColor = UIColor.cellBackground
		NCHeaderTableViewCell.appearance().backgroundColor = UIColor.background
		NCBackgroundView.appearance().backgroundColor = UIColor.background
		
		let searchBar = UISearchBar.appearance(whenContainedInInstancesOf: [NCTableView.self])
		searchBar.barTintColor = UIColor.background
		searchBar.tintColor = UIColor.white
		searchBar.setSearchFieldBackgroundImage(UIImage.searchFieldBackgroundImage(color: UIColor.separator), for: UIControlState.normal)
		searchBar.backgroundImage = UIImage.image(color: UIColor.background)
	}

}

