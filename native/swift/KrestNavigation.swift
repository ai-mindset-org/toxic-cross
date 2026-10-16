import Foundation

/// Ephemeral view state. Closing the panel never rewrites product preferences.
struct KrestNavigation {
    private(set) var current="now"
    private(set) var previous="now"
    mutating func select(_ view:String) {
        if view == "settings",current != "settings" {previous=current}
        current=view
    }
}

/// Local popover events may omit their window; explicit foreign windows and dialogs keep their keys.
enum KrestKeyScope {
    static func accepts(shown:Bool,modal:Bool,sheet:Bool,menu:Bool,eventWindow:Int?,panelWindow:Int?)->Bool {
        guard shown,!modal,!sheet,!menu,let panelWindow else{return false}
        return eventWindow == nil || eventWindow == panelWindow
    }
}
