import Cocoa
import FlutterMacOS
import UserNotifications

public class FlutterLocalNotificationsPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate, NSUserNotificationCenterDelegate {

    struct MethodCallArguments {
        static let presentAlert = "presentAlert"
        static let presentSound = "presentSound"
        static let presentBadge = "presentBadge"
        static let payload = "payload"
        static let defaultPresentAlert = "defaultPresentAlert"
        static let defaultPresentSound = "defaultPresentSound"
        static let defaultPresentBadge = "defaultPresentBadge"
        static let requestAlertPermission = "requestAlertPermission"
        static let requestSoundPermission = "requestSoundPermission"
        static let requestBadgePermission = "requestBadgePermission"
        static let requestCriticalPermission = "requestCriticalPermission"
        static let alert = "alert"
        static let sound = "sound"
        static let badge = "badge"
        static let critical = "critical"
        static let notificationLaunchedApp = "notificationLaunchedApp"
        static let id = "id"
        static let title = "title"
        static let subtitle = "subtitle"
        static let categoryIdentifier = "categoryIdentifier"
        static let body = "body"
        static let scheduledDateTime = "scheduledDateTime"
        static let timeZoneName = "timeZoneName"
        static let matchDateTimeComponents = "matchDateTimeComponents"
        static let platformSpecifics = "platformSpecifics"
        static let badgeNumber = "badgeNumber"
        static let repeatInterval = "repeatInterval"
        static let attachments = "attachments"
        static let identifier = "identifier"
        static let filePath = "filePath"
        static let threadIdentifier = "threadIdentifier"
        static let interruptionLevel = "interruptionLevel"
    }

    struct ErrorMessages {
        static let getActiveNotificationsErrorMessage = "macOS version must be 10.14 or newer to use getActiveNotifications"
    }

    struct ErrorCodes {
        static let unsupportedOSVersion = "unsupported_os_version"
    }

    struct DateFormatStrings {
        static let isoFormat = "yyyy-MM-dd'T'HH:mm:ss"
    }

    enum ScheduledNotificationRepeatFrequency: Int {
        case daily
        case weekly
    }

    enum DateTimeComponents: Int {
        case time
        case dayOfWeekAndTime
    }

    enum RepeatInterval: Int {
        case everyMinute
        case hourly
        case daily
        case weekly
    }

    var channel: FlutterMethodChannel
    var initialized = false
    var defaultPresentAlert = false
    var defaultPresentSound = false
    var defaultPresentBadge = false
    var launchPayload: String?
    var launchingAppFromNotification = false

    init(fromChannel channel: FlutterMethodChannel) {
        self.channel = channel
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dexterous.com/flutter/local_notifications", binaryMessenger: registrar.messenger)
        let instance = FlutterLocalNotificationsPlugin.init(fromChannel: channel)
        if #available(OSX 10.14, *) {
            let center = UNUserNotificationCenter.current()
            center.delegate = instance
        } else {
            let center = NSUserNotificationCenter.default
            center.delegate = instance
        }
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    @available(OSX 10.14, *)
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        var options: UNNotificationPresentationOptions = []
        let presentAlert = notification.request.content.userInfo[MethodCallArguments.presentAlert] as! Bool
        let presentSound = notification.request.content.userInfo[MethodCallArguments.presentSound] as! Bool
        let presentBadge = notification.request.content.userInfo[MethodCallArguments.presentBadge] as! Bool
        if presentAlert {
            options.insert(.alert)
        }
        if presentSound {
            options.insert(.sound)
        }
        if presentBadge {
            options.insert(.badge)
        }
        completionHandler(options)
    }

    @available(OSX 10.14, *)
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            let payload = response.notification.request.content.userInfo[MethodCallArguments.payload] as? String
            if initialized {
                handleSelectNotification(payload: payload)
            } else {
                launchPayload = payload
                launchingAppFromNotification = true
            }

            completionHandler()
        } else {
            let text = (response as? UNTextInputNotificationResponse)?.userText ?? ""

            // No isolate can be used for macOS until https://github.com/flutter/flutter/issues/65222 is resolved.
            //
            // Therefore, we call the regular method channel and let the macos plugin handle it appropriately.
            handleSelectNotificationAction(payload: [
                "notificationId": response.notification.request.identifier,
                "actionId": response.actionIdentifier,
                "input": text,
                "payload": response.notification.request.content.userInfo["payload"] as? String ?? ""
            ])

            completionHandler()
        }
    }

    public func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if notification.activationType == .contentsClicked {
            handleSelectNotification(payload: notification.userInfo![MethodCallArguments.payload] as? String)
        }
    }

    public func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call, result)
        case "requestPermissions":
            requestPermissions(call, result)
        case "getNotificationAppLaunchDetails":
            getNotificationAppLaunchDetails(result)
        case "cancel":
            cancel(call, result)
        case "cancelAll":
            cancelAll(result)
        case "pendingNotificationRequests":
            pendingNotificationRequests(result)
        case "getActiveNotifications":
            getActiveNotifications(result)
        case "show":
            show(call, result)
        case "zonedSchedule":
            zonedSchedule(call, result)
        case "periodicallyShow":
            periodicallyShow(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func initialize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: AnyObject]
        defaultPresentAlert = arguments[MethodCallArguments.defaultPresentAlert] as! Bool
        defaultPresentSound = arguments[MethodCallArguments.defaultPresentSound] as! Bool
        defaultPresentBadge = arguments[MethodCallArguments.defaultPresentBadge] as! Bool
        if #available(OSX 10.14, *) {
            let requestedAlertPermission = arguments[MethodCallArguments.requestAlertPermission] as! Bool
            let requestedSoundPermission = arguments[MethodCallArguments.requestSoundPermission] as! Bool
            let requestedBadgePermission = arguments[MethodCallArguments.requestBadgePermission] as! Bool
            let requestedCriticalPermission = arguments[MethodCallArguments.requestCriticalPermission] as! Bool

            configureNotificationCategories(arguments) {
                self.requestPermissionsImpl(
                    soundPermission: requestedSoundPermission,
                    alertPermission: requestedAlertPermission,
                    badgePermission: requestedBadgePermission,
                    criticalPermission: requestedCriticalPermission,
                    result: result
                )
            }

            initialized = true
        } else {
            result(true)
            initialized = true
        }
    }

    func configureNotificationCategories(_ arguments: [String: AnyObject],
                                         withCompletionHandler completionHandler: @escaping () -> Void) {
        if #available(OSX 10.14, *) {
            if let categories = arguments["notificationCategories"] as? [[String: AnyObject]] {
                var newCategories = Set<UNNotificationCategory>()

                for category in categories {
                    var newActions = [UNNotificationAction]()

                    if let actions = category["actions"] as? [[String: AnyObject]] {
                        for action in actions {
                            let type = action["type"] as! String
                            let identifier = action["identifier"] as! String
                            let title = action["title"] as! String
                            let options = action["options"] as! [Any]
                            if type == "plain" {
                                newActions.append(UNNotificationAction(
                                    identifier: identifier,
                                    title: title,
                                    options: Converters.parseNotificationActionOptions(options)
                                ))
                            } else if type == "text" {
                                let buttonTitle = action["buttonTitle"] as! String
                                let placeholder = action["placeholder"] as! String
                                newActions.append(UNTextInputNotificationAction(
                                    identifier: identifier,
                                    title: title,
                                    options: Converters.parseNotificationActionOptions(options),
                                    textInputButtonTitle: buttonTitle,
                                    textInputPlaceholder: placeholder
                                ))
                            }
                        }
                    }

                    let newCategory = UNNotificationCategory(
                        identifier: category["identifier"] as! String,
                        actions: newActions,
                        intentIdentifiers: [],
                        hiddenPreviewsBodyPlaceholder: nil,
                        categorySummaryFormat: nil,
                        options: Converters.parseNotificationCategoryOptions(category["options"] as! [NSNumber])
                    )

                    newCategories.insert(newCategory)

                }

                let center = UNUserNotificationCenter.current()
                center.getNotificationCategories { _  in
                    center.setNotificationCategories(newCategories)
                    completionHandler()
                }

            } else {
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }

    func requestPermissions(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if #available(OSX 10.14, *) {
            let arguments = call.arguments as! [String: AnyObject]
            let requestedAlertPermission = arguments[MethodCallArguments.alert] as! Bool
            let requestedSoundPermission = arguments[MethodCallArguments.sound] as! Bool
            let requestedBadgePermission = arguments[MethodCallArguments.badge] as! Bool
            let requestedCriticalPermission = arguments[MethodCallArguments.critical] as! Bool
            requestPermissionsImpl(soundPermission: requestedSoundPermission, alertPermission: requestedAlertPermission, badgePermission: requestedBadgePermission, criticalPermission: requestedCriticalPermission, result: result)
        } else {
            result(nil)
        }
    }

    func getNotificationAppLaunchDetails(_ result: @escaping FlutterResult) {
        if #available(OSX 10.14, *) {
            let appLaunchDetails: [String: Any?] = [MethodCallArguments.notificationLaunchedApp: launchingAppFromNotification, MethodCallArguments.payload: launchPayload]
            result(appLaunchDetails)
        } else {
            result(nil)
        }
    }

    func cancel(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if #available(OSX 10.14, *) {
            let center = UNUserNotificationCenter.current()
            let idsToRemove = [String(call.arguments as! Int)]
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            center.removeDeliveredNotifications(withIdentifiers: idsToRemove)
            result(nil)
        } else {
            let id = String(call.arguments as! Int)
            let center = NSUserNotificationCenter.default
            for scheduledNotification in center.scheduledNotifications {
                if scheduledNotification.identifier == id {
                    center.removeScheduledNotification(scheduledNotification)
                    break
                }
            }
            let notification = NSUserNotification.init()
            notification.identifier = id
            center.removeDeliveredNotification(notification)
            result(nil)
        }
    }

    func cancelAll(_ result: @escaping FlutterResult) {
        if #available(OSX 10.14, *) {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            result(nil)
        } else {
            let center = NSUserNotificationCenter.default
            for scheduledNotification in center.scheduledNotifications {
                center.removeScheduledNotification(scheduledNotification)
            }
            center.removeAllDeliveredNotifications()
            result(nil)
        }
    }

    func pendingNotificationRequests(_ result: @escaping FlutterResult) {
        if #available(OSX 10.14, *) {
            UNUserNotificationCenter.current().getPendingNotificationRequests { (requests) in
                var requestDictionaries: [[String: Any?]] = []
                for request in requests {
                    requestDictionaries.append([MethodCallArguments.id: Int(request.identifier) as Any, MethodCallArguments.title: request.content.title, MethodCallArguments.body: request.content.body, MethodCallArguments.payload: request.content.userInfo[MethodCallArguments.payload]])
                }
                result(requestDictionaries)
            }
        } else {
            var requestDictionaries: [[String: Any?]] = []
            let center = NSUserNotificationCenter.default
            for scheduledNotification in center.scheduledNotifications {
                requestDictionaries.append([MethodCallArguments.id: Int(scheduledNotification.identifier!) as Any, MethodCallArguments.title: scheduledNotification.title, MethodCallArguments.body: scheduledNotification.informativeText, MethodCallArguments.payload: scheduledNotification.userInfo![MethodCallArguments.payload]])
            }
            result(requestDictionaries)
        }
    }

    func getActiveNotifications(_ result: @escaping FlutterResult) {
        if #available(OSX 10.14, *) {
            UNUserNotificationCenter.current().getDeliveredNotifications { (requests) in
                var requestDictionaries: [[String: Any?]] = []
                for request in requests {
                    requestDictionaries.append([MethodCallArguments.id: Int(request.request.identifier) as Any, MethodCallArguments.title: request.request.content.title, MethodCallArguments.body: request.request.content.body, MethodCallArguments.payload: request.request.content.userInfo[MethodCallArguments.payload]])
                }
                result(requestDictionaries)
            }
        } else {
            result(FlutterError.init(code: ErrorCodes.unsupportedOSVersion, message: ErrorMessages.getActiveNotificationsErrorMessage, details: nil))
        }
    }

    func show(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if #available(OSX 10.14, *) {
            do {
                let arguments = call.arguments as! [String: AnyObject]
                let content = try buildUserNotificationContent(fromArguments: arguments)
                let center = UNUserNotificationCenter.current()
                let request = UNNotificationRequest(identifier: getIdentifier(fromArguments: arguments), content: content, trigger: nil)
                center.add(request)
                result(nil)
            } catch {
                result(buildFlutterError(forMethodCallName: call.method, withError: error))
            }
        } else {
            let arguments = call.arguments as! [String: AnyObject]
            let notification = buildNSUserNotification(fromArguments: arguments)
            NSUserNotificationCenter.default.deliver(notification)
            result(nil)
        }
    }

    func zonedSchedule(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if #available(OSX 10.14, *) {
            do {
                let arguments = call.arguments as! [String: AnyObject]
                let content = try buildUserNotificationContent(fromArguments: arguments)
                let trigger = buildUserNotificationCalendarTrigger(fromArguments: arguments)
                let center = UNUserNotificationCenter.current()
                let request = UNNotificationRequest(identifier: getIdentifier(fromArguments: arguments), content: content, trigger: trigger)
                center.add(request)
                result(nil)
            } catch {
                result(buildFlutterError(forMethodCallName: call.method, withError: error))
            }
        } else {
            let arguments = call.arguments as! [String: AnyObject]
            let notification = buildNSUserNotification(fromArguments: arguments)
            let scheduledDateTime = arguments[MethodCallArguments.scheduledDateTime] as! String
            let timeZoneName = arguments[MethodCallArguments.timeZoneName] as! String
            let timeZone = TimeZone.init(identifier: timeZoneName)
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = DateFormatStrings.isoFormat
            let date = dateFormatter.date(from: scheduledDateTime)!
            notification.deliveryDate = date
            notification.deliveryTimeZone = timeZone
            if let rawDateTimeComponents = arguments[MethodCallArguments.matchDateTimeComponents] as? Int {
                let dateTimeComponents = DateTimeComponents.init(rawValue: rawDateTimeComponents)!
                switch dateTimeComponents {
                case .time:
                    notification.deliveryRepeatInterval = DateComponents.init(day: 1)
                case .dayOfWeekAndTime:
                    notification.deliveryRepeatInterval = DateComponents.init(weekOfYear: 1)
                }
            }
            NSUserNotificationCenter.default.scheduleNotification(notification)
            result(nil)
        }
    }

    func periodicallyShow(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if #available(OSX 10.14, *) {
            do {
                let arguments = call.arguments as! [String: AnyObject]
                let content = try buildUserNotificationContent(fromArguments: arguments)
                let trigger = buildUserNotificationTimeIntervalTrigger(fromArguments: arguments)
                let center = UNUserNotificationCenter.current()
                let request = UNNotificationRequest(identifier: getIdentifier(fromArguments: arguments), content: content, trigger: trigger)
                center.add(request)
                result(nil)
            } catch {
                result(buildFlutterError(forMethodCallName: call.method, withError: error))
            }
        } else {
            let arguments = call.arguments as! [String: AnyObject]
            let notification = buildNSUserNotification(fromArguments: arguments)
            let rawRepeatInterval = arguments[MethodCallArguments.repeatInterval] as! Int
            let repeatInterval = RepeatInterval.init(rawValue: rawRepeatInterval)!
            switch repeatInterval {
            case .everyMinute:
                notification.deliveryDate = Date.init(timeIntervalSinceNow: 60)
                notification.deliveryRepeatInterval = DateComponents.init(minute: 1)
            case .hourly:
                notification.deliveryDate = Date.init(timeIntervalSinceNow: 60 * 60)
                notification.deliveryRepeatInterval = DateComponents.init(hour: 1)
            case .daily:
                notification.deliveryDate = Date.init(timeIntervalSinceNow: 60 * 60 * 24)
                notification.deliveryRepeatInterval = DateComponents.init(day: 1)
            case .weekly:
                notification.deliveryDate = Date.init(timeIntervalSinceNow: 60 * 60 * 24 * 7)
                notification.deliveryRepeatInterval = DateComponents.init(weekOfYear: 1)
            }
            NSUserNotificationCenter.default.scheduleNotification(notification)
            result(nil)
        }
    }

    @available(OSX 10.14, *)
    func buildUserNotificationContent(fromArguments arguments: [String: AnyObject]) throws -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        if let title = arguments[MethodCallArguments.title] as? String {
            content.title = title
        }
        if let subtitle = arguments[MethodCallArguments.subtitle] as? String {
            content.subtitle = subtitle
        }
        if let body = arguments[MethodCallArguments.body] as? String {
            content.body = body
        }
        var presentSound = defaultPresentSound
        var presentBadge = defaultPresentBadge
        var presentAlert = defaultPresentAlert
        if let platformSpecifics = arguments[MethodCallArguments.platformSpecifics] as? [String: AnyObject] {
            if let sound = platformSpecifics[MethodCallArguments.sound] as? String {
                content.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(sound))
            }
            if let badgeNumber = platformSpecifics[MethodCallArguments.badgeNumber] as? NSNumber {
                content.badge = badgeNumber
            }
            if !(platformSpecifics[MethodCallArguments.presentSound] is NSNull) && platformSpecifics[MethodCallArguments.presentSound] != nil {
                presentSound = platformSpecifics[MethodCallArguments.presentSound] as! Bool
            }
            if !(platformSpecifics[MethodCallArguments.presentAlert] is NSNull) && platformSpecifics[MethodCallArguments.presentAlert] != nil {
                presentAlert = platformSpecifics[MethodCallArguments.presentAlert] as! Bool
            }
            if !(platformSpecifics[MethodCallArguments.presentBadge] is NSNull) && platformSpecifics[MethodCallArguments.presentBadge] != nil {
                presentBadge = platformSpecifics[MethodCallArguments.presentBadge] as! Bool
            }
            if let threadIdentifier = platformSpecifics[MethodCallArguments.threadIdentifier] as? String {
                content.threadIdentifier = threadIdentifier
            }
            if let categoryIdentifier = platformSpecifics[MethodCallArguments.categoryIdentifier] as? String {
                content.categoryIdentifier = categoryIdentifier
            }
            if #available(macOS 12.0, *) {
              if let rawInterruptionLevel = platformSpecifics[MethodCallArguments.interruptionLevel] as? UInt {
                content.interruptionLevel = UNNotificationInterruptionLevel.init(rawValue: rawInterruptionLevel)!
              }
            }
            if let attachments = platformSpecifics[MethodCallArguments.attachments] as? [[String: AnyObject]] {
                content.attachments = []
                for attachment in attachments {
                    let identifier = attachment[MethodCallArguments.identifier] as! String
                    let filePath = attachment[MethodCallArguments.filePath] as! String
                    let notificationAttachment = try UNNotificationAttachment.init(identifier: identifier, url: URL.init(fileURLWithPath: filePath))
                    content.attachments.append(notificationAttachment)
                }
            }
        }
        content.userInfo = [MethodCallArguments.payload: arguments[MethodCallArguments.payload] as Any, MethodCallArguments.presentSound: presentSound, MethodCallArguments.presentBadge: presentBadge, MethodCallArguments.presentAlert: presentAlert]
        if presentSound && content.sound == nil {
            content.sound = UNNotificationSound.default
        }
        return content
    }

    func buildFlutterError(forMethodCallName methodCallName: String, withError error: Error) -> FlutterError {
        return FlutterError.init(code: "\(methodCallName)_error", message: error.localizedDescription, details: "\(error)")
    }

    @available(OSX 10.14, *)
    func buildUserNotificationCalendarTrigger(fromArguments arguments: [String: AnyObject]) -> UNCalendarNotificationTrigger {
        let scheduledDateTime = arguments[MethodCallArguments.scheduledDateTime] as! String
        let timeZoneName = arguments[MethodCallArguments.timeZoneName] as! String
        let timeZone = TimeZone.init(identifier: timeZoneName)
        let dateFormatter = DateFormatter.init()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = DateFormatStrings.isoFormat
        dateFormatter.timeZone = timeZone
        let date = dateFormatter.date(from: scheduledDateTime)!
        var calendar = Calendar.current
        calendar.timeZone = timeZone!
        if let rawDateTimeComponents = arguments[MethodCallArguments.matchDateTimeComponents] as? Int {
            let dateTimeComponents = DateTimeComponents.init(rawValue: rawDateTimeComponents)!
            switch dateTimeComponents {
            case .time:
                let dateComponents = calendar.dateComponents([.day, .hour, .minute, .second, .timeZone], from: date)
                return UNCalendarNotificationTrigger.init(dateMatching: dateComponents, repeats: true)
            case .dayOfWeekAndTime:
                let dateComponents = calendar.dateComponents([ .weekday, .hour, .minute, .second, .timeZone], from: date)
                return UNCalendarNotificationTrigger.init(dateMatching: dateComponents, repeats: true)
            }
        }
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone], from: date)
        return UNCalendarNotificationTrigger.init(dateMatching: dateComponents, repeats: false)
    }

    @available(OSX 10.14, *)
    func buildUserNotificationTimeIntervalTrigger(fromArguments arguments: [String: AnyObject]) -> UNTimeIntervalNotificationTrigger {
        let rawRepeatInterval = arguments[MethodCallArguments.repeatInterval] as! Int
        let repeatInterval = RepeatInterval.init(rawValue: rawRepeatInterval)!
        switch repeatInterval {
        case .everyMinute:
            return UNTimeIntervalNotificationTrigger.init(timeInterval: 60, repeats: true)
        case .hourly:
            return UNTimeIntervalNotificationTrigger.init(timeInterval: 60 * 60, repeats: true)
        case .daily:
            return UNTimeIntervalNotificationTrigger.init(timeInterval: 60 * 60 * 24, repeats: true)
        case .weekly:
            return UNTimeIntervalNotificationTrigger.init(timeInterval: 60 * 60 * 24 * 7, repeats: true)
        }

    }

    @available(OSX 10.14, *)
    func requestPermissionsImpl(soundPermission: Bool, alertPermission: Bool, badgePermission: Bool, criticalPermission: Bool, result: @escaping FlutterResult) {
        if !soundPermission && !alertPermission && !badgePermission && !criticalPermission {
            result(false)
            return
        }
        var options: UNAuthorizationOptions = []
        if soundPermission {
            options.insert(.sound)
        }
        if alertPermission {
            options.insert(.alert)
        }
        if badgePermission {
            options.insert(.badge)
        }
        if criticalPermission {
            options.insert(.criticalAlert)
        }
        UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, _) in
            result(granted)
        }
    }

    func buildNSUserNotification(fromArguments arguments: [String: AnyObject]) -> NSUserNotification {
        let notification = NSUserNotification.init()
        notification.identifier = getIdentifier(fromArguments: arguments)
        if let title = arguments[MethodCallArguments.title] as? String {
            notification.title = title
        }
        if let subtitle = arguments[MethodCallArguments.subtitle] as? String {
            notification.subtitle = subtitle
        }
        if let body = arguments[MethodCallArguments.body] as? String {
            notification.informativeText = body
        }
        var presentSound = defaultPresentSound
        if let platformSpecifics = arguments[MethodCallArguments.platformSpecifics] as? [String: AnyObject] {
            if let sound = platformSpecifics[MethodCallArguments.sound] as? String {
                notification.soundName = sound
            }

            if !(platformSpecifics[MethodCallArguments.presentSound] is NSNull) && platformSpecifics[MethodCallArguments.presentSound] != nil {
                presentSound = platformSpecifics[MethodCallArguments.presentSound] as! Bool
            }

        }
        notification.userInfo = [MethodCallArguments.payload: arguments[MethodCallArguments.payload] as Any]
        if presentSound && notification.soundName == nil {
            notification.soundName = NSUserNotificationDefaultSoundName
        }
        return notification
    }

    func getIdentifier(fromArguments arguments: [String: AnyObject]) -> String {
        return String(arguments[MethodCallArguments.id] as! Int)
    }

    func handleSelectNotification(payload: String?) {
        channel.invokeMethod("selectNotification", arguments: payload)
    }

    func handleSelectNotificationAction(payload: [String: Any]) {
        channel.invokeMethod("selectNotificationAction", arguments: payload)
    }
}
