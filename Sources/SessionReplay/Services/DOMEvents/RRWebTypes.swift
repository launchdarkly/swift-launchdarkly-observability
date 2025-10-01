import Foundation

public enum EventType: Int, Codable {
    case DomContentLoaded = 0,
         Load = 1,
         FullSnapshot = 2,
         IncrementalSnapshot = 3,
         Meta = 4,
         Custom = 5,
         Plugin = 6
}

public enum NodeType: Int, Codable {
    case Document = 0,
         DocumentType = 1,
         Element = 2,
         Text = 3,
         CDATA = 4,
         Comment = 5
}

public enum IncrementalSource: Int, Codable {
    case mutation = 0,
         mouseMove = 1,
         mouseInteraction = 2,
         scroll = 3,
         viewportResize = 4,
         input = 5,
         touchMove = 6,
         mediaInteraction = 7,
         styleSheetRule = 8,
         canvasMutation = 9,
         font,
         log,
         drag,
         styleDeclaration,
         selection,
         adoptedStyleSheet,
         customElement
}

public enum MouseInteractions: Int, Codable {
    case mouseUp = 0,
         mouseDown = 1,
         click = 2,
         contextMenu = 3,
         dblClick = 4,
         focus = 5,
         blur = 6,
         touchStart = 7,
         touchMove_Departed = 8,
         touchEnd = 9,
         touchCancel = 10
}

public enum CustomDataTag: String, Codable {
    case click = "Click"
    case focus = "Focus"
    case viewport = "Viewport"
    case reload = "Reload"
}
