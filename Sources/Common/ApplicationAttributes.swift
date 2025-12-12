import Foundation
import UIKit

public class ApplicationProperties {
    public static var name: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
}
