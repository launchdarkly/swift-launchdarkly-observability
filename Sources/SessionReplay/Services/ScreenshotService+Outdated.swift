import Foundation

enum ScreenshotServiceError: Error {
    case loadingJSONFailed(String)
    case networkError(Error)
    case decodingError(Error?)
}

extension ReplayPushService  {
//    func pushNotScreenshotItems(items: [EventQueueItem]) async throws {
//        guard let currentSession else {
//            return
//        }
//        guard items.isNotEmpty else { return }
//        
//        var events = [Event]()
//        for item in items {
//            switch item.payload {
//            case .screenshot:
//                continue
//                
//            case .tap(let touch):
//                tapEvent(touch: touch, events: &events, timestamp: item.timestamp)
//            }
//        }
//        
//        if events.isNotEmpty {
//            let input = PushPayloadVariables(sessionSecureId: currentSession.secureId, payloadId: "\(nextPayloadId)", events: events)
//            try await replayApiService.pushPayload(input)
//        }
// 
//        notScreenItems.removeAll()
//    }
    
//    func sendOld(items: [EventQueueItem]) async throws {
//              if currentSession == nil {
//                   let session = try await initializeSession(sessionSecureId: ReplaySessionGenerator.generateSecureID())
//                   try await identifySession(session: session)
//                   currentSession = session
//               }
//               
//               guard let currentSession else {
//                   return
//               }
//               
//               for item in items {
//                   switch item.payload {
//                   case .screenshot(let exportImage):
//                       guard lastExportImage != exportImage else {
//                           return
//                       }
//                       lastExportImage = exportImage
//                       let timestamp = item.timestamp
//                       
//                       if let imageId {
//                           try await pushNotScreenshotItems(items: notScreenItems)
//                           try await pushPayloadDrawImage(session: currentSession, timestamp: timestamp, exportImage: exportImage, imageId: imageId)
//                       } else {
//                           try await pushNotScreenshotItems(items: notScreenItems)
//                           try await pushPayloadFullSnapshot(session: currentSession, exportImage: exportImage, timestamp: timestamp)
//                           // fake mouse movement to trigger something
//                           try await pushPayload(session: currentSession, resource: "payload2", timestamp: timestamp)
//                       }
//                   default:
//                       notScreenItems.append(item)
//                   }
//               }
//               
//               try await pushNotScreenshotItems(items: notScreenItems)
//    }
//
    
    func initializeSessionOld(secureId: String) async throws -> InitializeSessionResponse {
        //        guard let urlPayload = Bundle.module.url(forResource: "payload", withExtension: "json") else {
        //            return
        //        }
        guard let jsonDict = Bundle.module.loadJSONDictionary(from: "initializeSession.json") else {
            throw ScreenshotServiceError.loadingJSONFailed("initializeSession.json")
        }
        
        // Update the variables in the JSON dictionary with the new session secure ID
        guard var variables = jsonDict["variables"] as? [String: Any] else {
            throw ScreenshotServiceError.loadingJSONFailed("variables")
        }
        
        variables["session_secure_id"] = secureId
        
        // Update the clientConfig to replace the placeholder with the actual session secure ID
        if let clientConfig = variables["clientConfig"] as? String {
            let updatedClientConfig = clientConfig.replacingOccurrences(of: "{session_secure_id}", with: secureId)
            variables["clientConfig"] = updatedClientConfig
        }
        
        // Update the jsonDict with the modified variables
        var updatedJsonDict = jsonDict
        updatedJsonDict["variables"] = variables
        
        let requestBodyData = try! JSONSerialization.data(withJSONObject: updatedJsonDict, options: [])
        print("Sending initializeSession:")
        print(String(data: requestBodyData, encoding: .utf8) ?? "Bad JSON")
        
        
        var request = URLRequest(url: replayApiService.gqlClient.endpoint)
        request.httpBody = requestBodyData
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("pub.observability.ld-stg.launchdarkly.com", forHTTPHeaderField: "authority")
        request.addValue("*/*", forHTTPHeaderField: "accept")
        request.addValue("gzip, deflate, br, zstd", forHTTPHeaderField: "accept-encoding")
        request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "accept-language")
        request.addValue("http://localhost:5173", forHTTPHeaderField: "origin")
        request.addValue("u=1, i", forHTTPHeaderField: "priority")
        request.addValue("http://localhost:5173/", forHTTPHeaderField: "referer")
        request.addValue("`Not;A=Brand`", forHTTPHeaderField: "sec-ch-ua")
        request.addValue("`99`", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.addValue("`macOS`", forHTTPHeaderField: "sec-ch-ua-platform")
        request.addValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.addValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.addValue("cross-site", forHTTPHeaderField: "sec-fetch-site")
        do {
            let (data, reponse) = try await URLSession.shared.data(for: request)
            print(String(data: data, encoding: .utf8) ?? "No data, response: \(reponse)")
            
            guard let sessionData = try? JSONDecoder().decode(InitializeSessionResponseWrapper.self, from: data) else {
                throw ScreenshotServiceError.decodingError(nil)
            }
            let session = sessionData.data.initializeSession
            print("Secure ID: \(session.secureId)")
            
            print("Session initialized - Secure ID: \(session.secureId)")
            return session
        } catch let error as DecodingError {
            throw ScreenshotServiceError.decodingError(error)
        } catch let error {
            throw ScreenshotServiceError.networkError(error)
        }
    }
    
    
    func addSessionProperties(session: InitializeSessionResponse) async throws {
        // guard let jsonDict = Bundle.module.loadJSONDictionary(from: "addSessionProperties.json") else {
        //     return
        // }
        
        // let requestBodyData = try! JSONSerialization.data(withJSONObject: jsonDict, options: [])
        
        // var request = URLRequest(url: URL(string: "https://pub.observability.ld-stg.launchdarkly.com/")!)
        
        let jsonDict: [String: Any] = [
            "query": "mutation addSessionProperties($session_secure_id: String!, $properties_object: Any) {\n  addSessionProperties(\n    session_secure_id: $session_secure_id\n    properties_object: $properties_object\n  )\n}",
            "variables": [
                "session_secure_id": session.secureId,
                "properties_object": [
                    "reload": "true"
                ]
            ],
            "operationName": "addSessionProperties"
        ]
        
        let requestBodyData = try! JSONSerialization.data(withJSONObject: jsonDict, options: [])
        
        
        var request = URLRequest(url: replayApiService.gqlClient.endpoint)
        request.httpBody = requestBodyData
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.addValue("", forHTTPHeaderField: "Referer")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print(String(data: data, encoding: .utf8) ?? "No data, response: \(response)")
        } catch {
            print("Error adding session properties: \(error)")
            throw ScreenshotServiceError.networkError(error)
        }
    }
    
    func pushPreparedPayload(_ preparedJsonDict: [String : Any]) async throws {
        let gql = """
                  mutation PushPayload(
                      $session_secure_id: String!
                      $payload_id: ID!
                      $events: ReplayEventsInput!
                      $messages: String!
                      $resources: String!
                      $web_socket_events: String!
                      $errors: [ErrorObjectInput]!
                      $is_beacon: Boolean
                      $has_session_unloaded: Boolean
                      $highlight_logs: String
                  ) {
                      pushPayload(
                          session_secure_id: $session_secure_id
                          payload_id: $payload_id
                          events: $events
                          messages: $messages
                          resources: $resources
                          web_socket_events: $web_socket_events
                          errors: $errors
                          is_beacon: $is_beacon
                          has_session_unloaded: $has_session_unloaded
                          highlight_logs: $highlight_logs
                      )
                  }     
        """
        
        let jsonDict: [String: Any] = [
            "query": gql,
            "variables": preparedJsonDict,
            "operationName": "PushPayload"
        ]
        
        let requestBodyData = try! JSONSerialization.data(withJSONObject: jsonDict, options: [])
        print("Sending pushPayload:")
        let strBody = String(data: requestBodyData, encoding: .utf8)
        print(strBody ?? "No data")
        
        var request = URLRequest(url: replayApiService.gqlClient.endpoint)
        request.httpBody = requestBodyData
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.addValue("", forHTTPHeaderField: "Referer")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("pushPayload:")
            let str = String(data: data, encoding: .utf8)
            print(str ?? "No data, response: \(response)")
            if str?.contains("errors") ?? false {
                throw ScreenshotServiceError.networkError(NSError(domain: "", code: 0, userInfo: nil))
            }
        } catch {
            print("Error pushing payload: \(error)")
            throw ScreenshotServiceError.networkError(error)
        }
    }
    
    func pushPayload(session: InitializeSessionResponse, resource: String, exportImage: ExportImage? = nil, timestamp: Int64) async throws {
        let imageNode = exportImage?.eventNode(id: 16)
        let preparedJsonDict = try preparePayload(filename: "\(resource).json",
                                                  session: session,
                                                  payloadId: "\(nextPayloadId)",
                                                  timestamp: timestamp,
                                                  imageNode: imageNode)
        
        try await pushPreparedPayload(preparedJsonDict)
    }
    
    func pushPayloadIncr(session: InitializeSessionResponse, resource: String, exportImage: ExportImage? = nil, timestamp: Int64) async throws {
        guard let imageNode = exportImage?.eventNode(id: 16) else { return }
        let preparedJsonDict = try preparePayload(filename: "\(resource).json",
                                                  session: session,
                                                  payloadId: "\(nextPayloadId)",
                                                  timestamp: Int64(Date().timeIntervalSince1970 * 1000.0),
                                                  imageNode: imageNode)
        
        try await pushPreparedPayload(preparedJsonDict)
    }
    
    func pushPayloadReplaceImg(session: InitializeSessionResponse, timestamp: Int64, exportImage: ExportImage? = nil) async throws {
        guard var eventNode = exportImage?.eventNode(id: 16) else { return }
        //let eventData = EventData(source: .mutation,
        //                          attributes: [EventData.Attributes(id: sid, attributes: eventNode.attributes)])
        let removal = EventData.Removal(parentId: 12,
                                        id: id)
        eventNode.id = nextId
        eventNode.rootId = 1
        let addition = EventData.Addition(parentId: 12,
                                          //nextId: .some(nil),
                                          node: eventNode)
        let eventData = EventData(source: .mutation,
                                  attributes: [],
                                  adds: [addition],
                                  removes: [removal])
        let event = Event(type: .IncrementalSnapshot, data: AnyEventData(eventData), timestamp: timestamp, _sid: nextSid)
        let input = PushPayloadVariables(sessionSecureId: session.secureId, payloadId: "\(nextPayloadId)", events: [event])
        try await replayApiService.pushPayload(input)
    }
    
    func processNode(_ nodedict: [String: Any], imageNode: EventNode?, exportImage: ExportImage? = nil) -> [String: Any] {
        guard let imageNode else { return nodedict }
        
        if nodedict["tag"] as? String == "Viewport", var payload = nodedict["payload"] as? [String: Any] {
            var nodedict = nodedict
            payload["width"] = imageNode.attributes?["width"]
            payload["height"] = imageNode.attributes?["height"]
            payload["availWidth"] = imageNode.attributes?["width"]
            payload["availHeight"] = imageNode.attributes?["height"]
            nodedict["payload"] = payload
            return nodedict
        } else if nodedict["tagName"] as? String == "canvas" {
            var nodedict = nodedict
            nodedict["attributes"] = imageNode.attributes
            return nodedict
        } else if nodedict["source"] as? Int == 0 {
            var nodedict = nodedict
            var attributes = imageNode.attributes ?? [:]
            attributes["rr_dataURL"] = nil
            attributes["height"] = "200"
            attributes["width"] = "100"
            var atdict: [String : Any] = ["id": imageNode.id, "attributes" : attributes]
            nodedict["attributes"] = [atdict]
            return nodedict
        }
        else if let children = nodedict["childNodes"] as? [[String: Any]] {
            var nodedict = nodedict
            nodedict["childNodes"] = children.map { processNode($0, imageNode: imageNode) }
            return nodedict
        } else if let data = nodedict["data"] as? [String: Any] {
            var nodedict = nodedict
            var data = processNode(data, imageNode: imageNode)
            if let _ = data["width"], let nWidth = imageNode.attributes?["width"], let iWidth = Int(nWidth) {
                data["width"] = iWidth * 110 / 100
            }
            if let _ = data["height"], let nHeight = imageNode.attributes?["height"], let iHeight = Int(nHeight) {
                data["height"] = iHeight * 110 / 100
            }
            nodedict["data"] = data
            return nodedict
        }
        else if let child = nodedict["node"] as? [String: Any] {
            var nodedict = nodedict
            nodedict["node"] = processNode(child, imageNode: imageNode)
            return nodedict
        }
        return nodedict
    }
    
    func preparePayload(filename: String,
                        session: InitializeSessionResponse,
                        payloadId: String,
                        timestamp: Int64,
                        imageNode: EventNode? = nil) throws -> [String: Any] {
        guard let jsonDict = Bundle.module.loadJSONDictionary(from: filename) else {
            throw ScreenshotServiceError.loadingJSONFailed(filename)
        }
        
        var updatedJsonDict = jsonDict
        updatedJsonDict["session_secure_id"] = session.secureId
        updatedJsonDict["payload_id"] = payloadId
        
        var events = updatedJsonDict["events"] as! [String: Any]
        var subEvents = events["events"] as! [[String: Any]]
        for (i, event) in subEvents.enumerated() {
            var event = event
            if event["timestamp"] != nil {
                event["timestamp"] = timestamp + Int64(i * 1)
            }
            event["_sid"] = nextSid
            subEvents[i] = processNode(event, imageNode: imageNode)
        }
        events["events"] = subEvents
        updatedJsonDict["events"] = events
        
        return updatedJsonDict
    }
    
}



// MARK: - Bundle Extension
extension Bundle {
    /// Load and parse a JSON file from the bundle into a dictionary
    /// - Parameter filename: The name of the JSON file (with or without .json extension)
    /// - Returns: A dictionary representation of the JSON file, or nil if loading/parsing fails
    func loadJSONDictionary(from filename: String) -> [String: Any]? {
        // Ensure the filename has the .json extension
        // BAD CODE here
        let jsonFilename = filename.hasSuffix(".json") ? filename : "\(filename).json"
        
        // Get the URL for the JSON file in the bundle
        guard let url = self.url(forResource: String(jsonFilename.dropLast(5)), withExtension: "json") else {
            print("Could not find \(jsonFilename) in bundle")
            return nil
        }
        
        do {
            // Load the data from the file
            let data = try Data(contentsOf: url)
            
            // Parse the JSON data into a dictionary
            guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print("Could not parse \(jsonFilename) as dictionary")
                return nil
            }
            
            return jsonObject
        } catch {
            print("Error loading \(jsonFilename): \(error)")
            return nil
        }
    }
    
    func loadString(from filename: String) -> String? {
        // Ensure the filename has the .txt extension
        // BAD CODE here
        let txtFilename = filename.hasSuffix(".txt") ? filename : "\(filename).txt"
        
        // Get the URL for the TXT file in the bundle
        guard let url = self.url(forResource: String(txtFilename.dropLast(4)), withExtension: "txt") else {
            print("Could not find \(txtFilename) in bundle")
            return nil
        }
        
        do {
            // Load the data from the file
            let str = try String(contentsOf: url, encoding: .utf8)
            return str
        } catch {
            print("Error loading \(txtFilename): \(error)")
            return nil
        }
    }
}
