//
//  UIStoryboard+NC.swift
//  Neocom
//
//  Created by Artem Shimanski on 03.09.2018.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import Foundation

extension UIStoryboard {
	static var main: UIStoryboard { return UIStoryboard(name: "Main", bundle: nil) }
	static var database: UIStoryboard { return UIStoryboard(name: "Database", bundle: nil) }
	static var character: UIStoryboard { return UIStoryboard(name: "Character", bundle: nil) }
	static var business: UIStoryboard { return UIStoryboard(name: "Business", bundle: nil) }
	static var killReports: UIStoryboard { return UIStoryboard(name: "KillReports", bundle: nil) }
	static var fitting: UIStoryboard { return UIStoryboard(name: "Fitting", bundle: nil) }
}
