//
//  Extension.swift
//  medra
//
//  Created by admin on 2025/11/26.
//

#if os(iOS)
extension UIDevice {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    static var isPortrait : Bool {
        UIDevice.current.orientation.isPortrait
    }
    
    static var width: CGFloat = UIScreen.main.bounds.width
    static var height: CGFloat = UIScreen.main.bounds.height
}
#endif
