public enum AttributeValue: Hashable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case array(Array<AttributeValue>)
    case set(Dictionary<String, AttributeValue>)
}
