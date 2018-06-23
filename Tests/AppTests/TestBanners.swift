//
//  TestBanners.swift
//  AppTests
//
//  Created by Scott Lucas on 6/21/18.
//

import Foundation

struct Banners {
    static let start = """

**************************** START %@ ***********************************

"""
    static let finish = """

**************************** FINISH %@ **********************************

"""
    
    static let pass =
    """
**************************** PASS %@ *****************************************

"""
    static let fail =
    """

**************************** FAIL ********************************************
    Error: %@
    Function: %@
    Line: %d

"""}
