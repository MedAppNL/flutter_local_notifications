#import "FlutterLocalNotificationsPlugin.h"
#import "ActionEventSink.h"
#import "Converters.h"
#import "FlutterEngineManager.h"

@implementation FlutterLocalNotificationsPlugin {
  FlutterMethodChannel *_channel;
  bool _displayAlert;
  bool _playSound;
  bool _updateBadge;
  bool _initialized;
  bool _launchingAppFromNotification;
  NSObject<FlutterPluginRegistrar> *_registrar;
  NSString *_launchPayload;
  FlutterEngineManager *_flutterEngineManager;
}

static FlutterPluginRegistrantCallback registerPlugins;
static ActionEventSink *actionEventSink;

NSString *const INITIALIZE_METHOD = @"initialize";
NSString *const GET_CALLBACK_METHOD = @"getCallbackHandle";
NSString *const SHOW_METHOD = @"show";
NSString *const ZONED_SCHEDULE_METHOD = @"zonedSchedule";
NSString *const PERIODICALLY_SHOW_METHOD = @"periodicallyShow";
NSString *const CANCEL_METHOD = @"cancel";
NSString *const CANCEL_ALL_METHOD = @"cancelAll";
NSString *const CANCEL_ALL_PENDING_METHOD = @"cancelAllPending";
NSString *const PENDING_NOTIFICATIONS_REQUESTS_METHOD =
    @"pendingNotificationRequests";
NSString *const GET_ACTIVE_NOTIFICATIONS_METHOD = @"getActiveNotifications";
NSString *const GET_NOTIFICATION_APP_LAUNCH_DETAILS_METHOD =
    @"getNotificationAppLaunchDetails";
NSString *const CHANNEL = @"dexterous.com/flutter/local_notifications";
NSString *const CALLBACK_CHANNEL =
    @"dexterous.com/flutter/local_notifications_background";
NSString *const ON_NOTIFICATION_METHOD = @"onNotification";
NSString *const DID_RECEIVE_LOCAL_NOTIFICATION = @"didReceiveLocalNotification";
NSString *const REQUEST_PERMISSIONS_METHOD = @"requestPermissions";

NSString *const DAY = @"day";

NSString *const REQUEST_SOUND_PERMISSION = @"requestSoundPermission";
NSString *const REQUEST_ALERT_PERMISSION = @"requestAlertPermission";
NSString *const REQUEST_BADGE_PERMISSION = @"requestBadgePermission";
NSString *const REQUEST_CRITICAL_PERMISSION = @"requestCriticalPermission";
NSString *const SOUND_PERMISSION = @"sound";
NSString *const ALERT_PERMISSION = @"alert";
NSString *const BADGE_PERMISSION = @"badge";
NSString *const CRITICAL_PERMISSION = @"critical";
NSString *const DEFAULT_PRESENT_ALERT = @"defaultPresentAlert";
NSString *const DEFAULT_PRESENT_SOUND = @"defaultPresentSound";
NSString *const DEFAULT_PRESENT_BADGE = @"defaultPresentBadge";
NSString *const CALLBACK_DISPATCHER = @"callbackDispatcher";
NSString *const ON_NOTIFICATION_CALLBACK_DISPATCHER =
    @"onNotificationCallbackDispatcher";
NSString *const PLATFORM_SPECIFICS = @"platformSpecifics";
NSString *const ID = @"id";
NSString *const TITLE = @"title";
NSString *const SUBTITLE = @"subtitle";
NSString *const BODY = @"body";
NSString *const SOUND = @"sound";
NSString *const ATTACHMENTS = @"attachments";
NSString *const ATTACHMENT_IDENTIFIER = @"identifier";
NSString *const ATTACHMENT_FILE_PATH = @"filePath";
NSString *const INTERRUPTION_LEVEL = @"interruptionLevel";
NSString *const THREAD_IDENTIFIER = @"threadIdentifier";
NSString *const PRESENT_ALERT = @"presentAlert";
NSString *const PRESENT_SOUND = @"presentSound";
NSString *const PRESENT_BADGE = @"presentBadge";
NSString *const BADGE_NUMBER = @"badgeNumber";
NSString *const MILLISECONDS_SINCE_EPOCH = @"millisecondsSinceEpoch";
NSString *const REPEAT_INTERVAL = @"repeatInterval";
NSString *const REPEAT_TIME = @"repeatTime";
NSString *const HOUR = @"hour";
NSString *const MINUTE = @"minute";
NSString *const SECOND = @"second";
NSString *const SCHEDULED_DATE_TIME = @"scheduledDateTime";
NSString *const TIME_ZONE_NAME = @"timeZoneName";
NSString *const MATCH_DATE_TIME_COMPONENTS = @"matchDateTimeComponents";
NSString *const UILOCALNOTIFICATION_DATE_INTERPRETATION =
    @"uiLocalNotificationDateInterpretation";

NSString *const NOTIFICATION_ID = @"NotificationId";
NSString *const PAYLOAD = @"payload";
NSString *const NOTIFICATION_LAUNCHED_APP = @"notificationLaunchedApp";

NSString *const UNSUPPORTED_OS_VERSION_ERROR_CODE = @"unsupported_os_version";
NSString *const GET_ACTIVE_NOTIFICATIONS_ERROR_MESSAGE =
    @"iOS version must be 10.0 or newer to use getActiveNotifications";

typedef NS_ENUM(NSInteger, RepeatInterval) {
  EveryMinute,
  Hourly,
  Daily,
  Weekly
};

typedef NS_ENUM(NSInteger, DateTimeComponents) {
  Time,
  DayOfWeekAndTime,
  DayOfMonthAndTime,
  DateAndTime
};

typedef NS_ENUM(NSInteger, UILocalNotificationDateInterpretation) {
  AbsoluteGMTTime,
  WallClockTime
};

static FlutterError *getFlutterError(NSError *error) {
  return [FlutterError
      errorWithCode:[NSString stringWithFormat:@"Error %d", (int)error.code]
            message:error.localizedDescription
            details:error.domain];
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:CHANNEL
                                  binaryMessenger:[registrar messenger]];

  FlutterLocalNotificationsPlugin *instance =
      [[FlutterLocalNotificationsPlugin alloc] initWithChannel:channel
                                                     registrar:registrar];

  if ([FlutterEngineManager shouldAddAppDelegateToRegistrar:registrar]) {
    [registrar addApplicationDelegate:instance];
  }

  [registrar addMethodCallDelegate:instance channel:channel];
}

+ (void)setPluginRegistrantCallback:(FlutterPluginRegistrantCallback)callback {
  registerPlugins = callback;
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel
                      registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];

  if (self) {
    _channel = channel;
    _registrar = registrar;
    _flutterEngineManager = [[FlutterEngineManager alloc] init];
  }

  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
  if ([INITIALIZE_METHOD isEqualToString:call.method]) {
    [self initialize:call.arguments result:result];
  } else if ([GET_CALLBACK_METHOD isEqualToString:call.method]) {
    result([_flutterEngineManager getCallbackHandle]);
  } else if ([SHOW_METHOD isEqualToString:call.method]) {

    [self show:call.arguments result:result];
  } else if ([ZONED_SCHEDULE_METHOD isEqualToString:call.method]) {
    [self zonedSchedule:call.arguments result:result];
  } else if ([PERIODICALLY_SHOW_METHOD isEqualToString:call.method]) {
    [self periodicallyShow:call.arguments result:result];
  } else if ([REQUEST_PERMISSIONS_METHOD isEqualToString:call.method]) {
    [self requestPermissions:call.arguments result:result];
  } else if ([CANCEL_METHOD isEqualToString:call.method]) {
    [self cancel:((NSNumber *)call.arguments) result:result];
  } else if ([CANCEL_ALL_METHOD isEqualToString:call.method]) {
    [self cancelAll:result];
  } else if ([CANCEL_ALL_PENDING_METHOD isEqualToString:call.method]) {
    [self cancelAllPending:result];
  } else if ([GET_NOTIFICATION_APP_LAUNCH_DETAILS_METHOD
                 isEqualToString:call.method]) {
    NSDictionary *notificationAppLaunchDetails = [NSDictionary
        dictionaryWithObjectsAndKeys:
            [NSNumber numberWithBool:_launchingAppFromNotification],
            NOTIFICATION_LAUNCHED_APP, _launchPayload, PAYLOAD, nil];
    result(notificationAppLaunchDetails);
  } else if ([PENDING_NOTIFICATIONS_REQUESTS_METHOD
                 isEqualToString:call.method]) {
    [self pendingNotificationRequests:result];
  } else if ([GET_ACTIVE_NOTIFICATIONS_METHOD isEqualToString:call.method]) {
    [self getActiveNotifications:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)pendingUserNotificationRequests:(FlutterResult _Nonnull)result
    NS_AVAILABLE_IOS(10.0) {
  UNUserNotificationCenter *center =
      [UNUserNotificationCenter currentNotificationCenter];
  [center getPendingNotificationRequestsWithCompletionHandler:^(
              NSArray<UNNotificationRequest *> *_Nonnull requests) {
    NSMutableArray<NSMutableDictionary<NSString *, NSObject *> *>
        *pendingNotificationRequests =
            [[NSMutableArray alloc] initWithCapacity:[requests count]];
    for (UNNotificationRequest *request in requests) {
      NSMutableDictionary *pendingNotificationRequest =
          [[NSMutableDictionary alloc] init];
      pendingNotificationRequest[ID] =
          request.content.userInfo[NOTIFICATION_ID];
      if (request.content.title != nil) {
        pendingNotificationRequest[TITLE] = request.content.title;
      }
      if (request.content.body != nil) {
        pendingNotificationRequest[BODY] = request.content.body;
      }
      if (request.content.userInfo[PAYLOAD] != [NSNull null]) {
        pendingNotificationRequest[PAYLOAD] = request.content.userInfo[PAYLOAD];
      }
      [pendingNotificationRequests addObject:pendingNotificationRequest];
    }
    result(pendingNotificationRequests);
  }];
}

- (void)activeUserNotificationRequests:(FlutterResult _Nonnull)result
    NS_AVAILABLE_IOS(10.0) {
  UNUserNotificationCenter *center =
      [UNUserNotificationCenter currentNotificationCenter];
  [center getDeliveredNotificationsWithCompletionHandler:^(
              NSArray<UNNotification *> *_Nonnull notifications) {
    NSMutableArray<NSMutableDictionary<NSString *, NSObject *> *>
        *activeNotifications =
            [[NSMutableArray alloc] initWithCapacity:[notifications count]];
    for (UNNotification *notification in notifications) {
      NSMutableDictionary *activeNotification =
          [[NSMutableDictionary alloc] init];
      activeNotification[ID] =
          notification.request.content.userInfo[NOTIFICATION_ID];
      if (notification.request.content.title != nil) {
        activeNotification[TITLE] = notification.request.content.title;
      }
      if (notification.request.content.body != nil) {
        activeNotification[BODY] = notification.request.content.body;
      }
      if (notification.request.content.userInfo[PAYLOAD] != [NSNull null]) {
        activeNotification[PAYLOAD] =
            notification.request.content.userInfo[PAYLOAD];
      }
      [activeNotifications addObject:activeNotification];
    }
    result(activeNotifications);
  }];
}

- (void)pendingLocalNotificationRequests:(FlutterResult _Nonnull)result {
  NSArray *notifications =
      [UIApplication sharedApplication].scheduledLocalNotifications;
  NSMutableArray<NSDictionary<NSString *, NSObject *> *>
      *pendingNotificationRequests =
          [[NSMutableArray alloc] initWithCapacity:[notifications count]];
  for (int i = 0; i < [notifications count]; i++) {
    UILocalNotification *localNotification = [notifications objectAtIndex:i];
    NSMutableDictionary *pendingNotificationRequest =
        [[NSMutableDictionary alloc] init];
    pendingNotificationRequest[ID] =
        localNotification.userInfo[NOTIFICATION_ID];
    if (localNotification.userInfo[TITLE] != [NSNull null]) {
      pendingNotificationRequest[TITLE] = localNotification.userInfo[TITLE];
    }
    if (localNotification.alertBody) {
      pendingNotificationRequest[BODY] = localNotification.alertBody;
    }
    if (localNotification.userInfo[PAYLOAD] != [NSNull null]) {
      pendingNotificationRequest[PAYLOAD] = localNotification.userInfo[PAYLOAD];
    }
    [pendingNotificationRequests addObject:pendingNotificationRequest];
  }
  result(pendingNotificationRequests);
}

- (void)pendingNotificationRequests:(FlutterResult _Nonnull)result {
  if (@available(iOS 10.0, *)) {
    [self pendingUserNotificationRequests:result];
  } else {
    [self pendingLocalNotificationRequests:result];
  }
}

/// Extracts notification categories from [arguments] and configures them as
/// appropriate.
///
/// This code will simply return the `completionHandler` if not running on a
/// compatible iOS version or when no categories were specified in [arguments].
- (void)configureNotificationCategories:(NSDictionary *_Nonnull)arguments
                  withCompletionHandler:(void (^)(void))completionHandler {
  if (@available(iOS 10.0, *)) {
    if ([self containsKey:@"notificationCategories" forDictionary:arguments]) {
      NSMutableSet<UNNotificationCategory *> *newCategories =
          [NSMutableSet set];

      NSArray *categories = arguments[@"notificationCategories"];

      for (NSDictionary *category in categories) {
        NSMutableArray<UNNotificationAction *> *newActions =
            [NSMutableArray array];

        NSArray *actions = category[@"actions"];
        for (NSDictionary *action in actions) {
          NSString *type = action[@"type"];
          NSString *identifier = action[@"identifier"];
          NSString *title = action[@"title"];
          UNNotificationActionOptions options =
              [Converters parseNotificationActionOptions:action[@"options"]];

          if ([type isEqualToString:@"plain"]) {
            [newActions
                addObject:[UNNotificationAction actionWithIdentifier:identifier
                                                               title:title
                                                             options:options]];
          } else if ([type isEqualToString:@"text"]) {
            NSString *buttonTitle = action[@"buttonTitle"];
            NSString *placeholder = action[@"placeholder"];
            [newActions addObject:[UNTextInputNotificationAction
                                      actionWithIdentifier:identifier
                                                     title:title
                                                   options:options
                                      textInputButtonTitle:buttonTitle
                                      textInputPlaceholder:placeholder]];
          }
        }

        UNNotificationCategory *newCategory = [UNNotificationCategory
            categoryWithIdentifier:category[@"identifier"]
                           actions:newActions
                 intentIdentifiers:@[]
                           options:[Converters parseNotificationCategoryOptions:
                                                   category[@"options"]]];

        [newCategories addObject:newCategory];
      }

      if (newCategories.count > 0) {
        UNUserNotificationCenter *center =
            [UNUserNotificationCenter currentNotificationCenter];
        [center getNotificationCategoriesWithCompletionHandler:^(
                    NSSet<UNNotificationCategory *> *_Nonnull existing) {
          [center setNotificationCategories:
                      [existing setByAddingObjectsFromSet:newCategories]];

          completionHandler();
        }];
      } else {
        completionHandler();
      }
    }
  } else {
    completionHandler();
  }
}

- (void)getActiveNotifications:(FlutterResult _Nonnull)result {
  if (@available(iOS 10.0, *)) {
    [self activeUserNotificationRequests:result];
  } else {
    result([FlutterError errorWithCode:UNSUPPORTED_OS_VERSION_ERROR_CODE
                               message:GET_ACTIVE_NOTIFICATIONS_ERROR_MESSAGE
                               details:nil]);
  }
}

- (void)initialize:(NSDictionary *_Nonnull)arguments
            result:(FlutterResult _Nonnull)result {
  if ([self containsKey:DEFAULT_PRESENT_ALERT forDictionary:arguments]) {
    _displayAlert = [[arguments objectForKey:DEFAULT_PRESENT_ALERT] boolValue];
  }
  if ([self containsKey:DEFAULT_PRESENT_SOUND forDictionary:arguments]) {
    _playSound = [[arguments objectForKey:DEFAULT_PRESENT_SOUND] boolValue];
  }
  if ([self containsKey:DEFAULT_PRESENT_BADGE forDictionary:arguments]) {
    _updateBadge = [[arguments objectForKey:DEFAULT_PRESENT_BADGE] boolValue];
  }
  bool requestedSoundPermission = false;
  bool requestedAlertPermission = false;
  bool requestedBadgePermission = false;
  bool requestedCriticalPermission = false;
  if ([self containsKey:REQUEST_SOUND_PERMISSION forDictionary:arguments]) {
    requestedSoundPermission = [arguments[REQUEST_SOUND_PERMISSION] boolValue];
  }
  if ([self containsKey:REQUEST_ALERT_PERMISSION forDictionary:arguments]) {
    requestedAlertPermission = [arguments[REQUEST_ALERT_PERMISSION] boolValue];
  }
  if ([self containsKey:REQUEST_BADGE_PERMISSION forDictionary:arguments]) {
    requestedBadgePermission = [arguments[REQUEST_BADGE_PERMISSION] boolValue];
  }
  if ([self containsKey:REQUEST_CRITICAL_PERMISSION forDictionary:arguments]) {
    requestedCriticalPermission =
        [arguments[REQUEST_CRITICAL_PERMISSION] boolValue];
  }

  if ([self containsKey:@"dispatcher_handle" forDictionary:arguments] &&
      [self containsKey:@"callback_handle" forDictionary:arguments]) {
    [_flutterEngineManager
        registerDispatcherHandle:arguments[@"dispatcher_handle"]
                  callbackHandle:arguments[@"callback_handle"]];
  }

  // Configure the notification categories before requesting permissions
  [self configureNotificationCategories:arguments
                  withCompletionHandler:^{
                    // Once notification categories are set up, the permissions
                    // request will pick them up properly.
                    [self requestPermissionsImpl:requestedSoundPermission
                                 alertPermission:requestedAlertPermission
                                 badgePermission:requestedBadgePermission
                              criticalPermission:requestedCriticalPermission
                                          result:result];
                  }];

  _initialized = true;
}
- (void)requestPermissions:(NSDictionary *_Nonnull)arguments

                    result:(FlutterResult _Nonnull)result {
  bool soundPermission = false;
  bool alertPermission = false;
  bool badgePermission = false;
  bool criticalPermission = false;
  if ([self containsKey:SOUND_PERMISSION forDictionary:arguments]) {
    soundPermission = [arguments[SOUND_PERMISSION] boolValue];
  }
  if ([self containsKey:ALERT_PERMISSION forDictionary:arguments]) {
    alertPermission = [arguments[ALERT_PERMISSION] boolValue];
  }
  if ([self containsKey:BADGE_PERMISSION forDictionary:arguments]) {
    badgePermission = [arguments[BADGE_PERMISSION] boolValue];
  }
  if ([self containsKey:CRITICAL_PERMISSION forDictionary:arguments]) {
    criticalPermission = [arguments[CRITICAL_PERMISSION] boolValue];
  }
  [self requestPermissionsImpl:soundPermission
               alertPermission:alertPermission
               badgePermission:badgePermission
            criticalPermission:criticalPermission
                        result:result];
}

- (void)requestPermissionsImpl:(bool)soundPermission
               alertPermission:(bool)alertPermission
               badgePermission:(bool)badgePermission
            criticalPermission:(bool)criticalPermission
                        result:(FlutterResult _Nonnull)result {
  if (!soundPermission && !alertPermission && !badgePermission &&
      !criticalPermission) {
    result(@NO);
    return;
  }
    UNUserNotificationCenter *center =
        [UNUserNotificationCenter currentNotificationCenter];

    UNAuthorizationOptions authorizationOptions = 0;
    if (soundPermission) {
      authorizationOptions += UNAuthorizationOptionSound;
    }
    if (alertPermission) {
      authorizationOptions += UNAuthorizationOptionAlert;
    }
    if (badgePermission) {
      authorizationOptions += UNAuthorizationOptionBadge;
    }
    if (@available(iOS 12.0, *)) {
      if (criticalPermission) {
        authorizationOptions += UNAuthorizationOptionCriticalAlert;
      }
    }
    [center requestAuthorizationWithOptions:(authorizationOptions)
                          completionHandler:^(BOOL granted,
                                              NSError *_Nullable error) {
                            result(@(granted));
                          }];
}


- (NSString *)getIdentifier:(id)arguments {
  return [arguments[ID] stringValue];
}

- (void)show:(NSDictionary *_Nonnull)arguments
      result:(FlutterResult _Nonnull)result {
    UNMutableNotificationContent *content =
        [self buildStandardNotificationContent:arguments result:result];
  UNNotificationRequest *notificationRequest =
      [UNNotificationRequest requestWithIdentifier:[self getIdentifier:arguments]
                                           content:content
                                           trigger:nil];
  UNUserNotificationCenter *center =
      [UNUserNotificationCenter currentNotificationCenter];
  [center addNotificationRequest:notificationRequest
           withCompletionHandler:^(NSError *_Nullable error) {
             if (error == nil) {
               result(nil);
               return;
             }
             result(getFlutterError(error));
           }];
}

- (void)zonedSchedule:(NSDictionary *_Nonnull)arguments
               result:(FlutterResult _Nonnull)result {
    UNMutableNotificationContent *content =
        [self buildStandardNotificationContent:arguments result:result];
    UNCalendarNotificationTrigger *trigger =
        [self buildUserNotificationCalendarTrigger:arguments];
  UNNotificationRequest *notificationRequest =
      [UNNotificationRequest requestWithIdentifier:[self getIdentifier:arguments]
                                           content:content
                                           trigger:trigger];
  UNUserNotificationCenter *center =
      [UNUserNotificationCenter currentNotificationCenter];
  [center addNotificationRequest:notificationRequest
           withCompletionHandler:^(NSError *_Nullable error) {
             if (error == nil) {
               result(nil);
               return;
             }
             result(getFlutterError(error));
           }];
}

- (void)periodicallyShow:(NSDictionary *_Nonnull)arguments
                  result:(FlutterResult _Nonnull)result {
    UNMutableNotificationContent *content =
        [self buildStandardNotificationContent:arguments result:result];
    UNTimeIntervalNotificationTrigger *trigger =
        [self buildUserNotificationTimeIntervalTrigger:arguments];
  UNNotificationRequest *notificationRequest =
      [UNNotificationRequest requestWithIdentifier:[self getIdentifier:arguments]
                                           content:content
                                           trigger:trigger];
  UNUserNotificationCenter *center =
      [UNUserNotificationCenter currentNotificationCenter];
  [center addNotificationRequest:notificationRequest
           withCompletionHandler:^(NSError *_Nullable error) {
             if (error == nil) {
               result(nil);
               return;
             }
             result(getFlutterError(error));
           }];
}

- (void)cancel:(NSNumber *)id result:(FlutterResult _Nonnull)result {
  if (@available(iOS 10.0, *)) {
    UNUserNotificationCenter *center =
        [UNUserNotificationCenter currentNotificationCenter];
    NSArray *idsToRemove =
        [[NSArray alloc] initWithObjects:[id stringValue], nil];
    [center removePendingNotificationRequestsWithIdentifiers:idsToRemove];
    [center removeDeliveredNotificationsWithIdentifiers:idsToRemove];
  } else {
    NSArray *notifications =
        [UIApplication sharedApplication].scheduledLocalNotifications;
    for (int i = 0; i < [notifications count]; i++) {
      UILocalNotification *localNotification = [notifications objectAtIndex:i];
      NSNumber *userInfoNotificationId =
          localNotification.userInfo[NOTIFICATION_ID];
      if ([userInfoNotificationId longValue] == [id longValue]) {
        [[UIApplication sharedApplication]
            cancelLocalNotification:localNotification];
        break;
      }
    }
  }
  result(nil);
}

- (void)cancelAllPending:(FlutterResult _Nonnull)result {
  if (@available(iOS 10.0, *)) {
    UNUserNotificationCenter *center =
        [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllPendingNotificationRequests];
  } else {
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
  }
  result(nil);
}

- (void)cancelAll:(FlutterResult _Nonnull)result {
  if (@available(iOS 10.0, *)) {
    UNUserNotificationCenter *center =
        [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllPendingNotificationRequests];
    [center removeAllDeliveredNotifications];
  } else {
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
  }
  result(nil);
}

- (UNMutableNotificationContent *)
    buildStandardNotificationContent:(NSDictionary *)arguments
                              result:(FlutterResult _Nonnull)result
    API_AVAILABLE(ios(10.0)) {
  UNMutableNotificationContent *content =
      [[UNMutableNotificationContent alloc] init];
  if ([self containsKey:TITLE forDictionary:arguments]) {
    content.title = arguments[TITLE];
  }
  if ([self containsKey:BODY forDictionary:arguments]) {
    content.body = arguments[BODY];
  }
  bool presentAlert = _displayAlert;
  bool presentSound = _playSound;
  bool presentBadge = _updateBadge;
  if (arguments[PLATFORM_SPECIFICS] != [NSNull null]) {
    NSDictionary *platformSpecifics = arguments[PLATFORM_SPECIFICS];
    if ([self containsKey:PRESENT_ALERT forDictionary:platformSpecifics]) {
      presentAlert = [[platformSpecifics objectForKey:PRESENT_ALERT] boolValue];
    }
    if ([self containsKey:PRESENT_SOUND forDictionary:platformSpecifics]) {
      presentSound = [[platformSpecifics objectForKey:PRESENT_SOUND] boolValue];
    }
    if ([self containsKey:PRESENT_BADGE forDictionary:platformSpecifics]) {
      presentBadge = [[platformSpecifics objectForKey:PRESENT_BADGE] boolValue];
    }
    if ([self containsKey:BADGE_NUMBER forDictionary:platformSpecifics]) {
      content.badge = [platformSpecifics objectForKey:BADGE_NUMBER];
    }
    if ([self containsKey:THREAD_IDENTIFIER forDictionary:platformSpecifics]) {
      content.threadIdentifier = platformSpecifics[THREAD_IDENTIFIER];
    }
    if ([self containsKey:ATTACHMENTS forDictionary:platformSpecifics]) {
      NSArray<NSDictionary *> *attachments = platformSpecifics[ATTACHMENTS];
      if (attachments.count > 0) {
        NSMutableArray<UNNotificationAttachment *> *notificationAttachments =
            [NSMutableArray arrayWithCapacity:attachments.count];
        for (NSDictionary *attachment in attachments) {
          NSError *error;
          UNNotificationAttachment *notificationAttachment =
              [UNNotificationAttachment
                  attachmentWithIdentifier:attachment[ATTACHMENT_IDENTIFIER]
                                       URL:[NSURL
                                               fileURLWithPath:
                                                   attachment
                                                       [ATTACHMENT_FILE_PATH]]
                                   options:nil
                                     error:&error];
          if (error) {
            result(getFlutterError(error));
            return nil;
          }
          [notificationAttachments addObject:notificationAttachment];
        }
        content.attachments = notificationAttachments;
      }
    }
    if ([self containsKey:SOUND forDictionary:platformSpecifics]) {
      content.sound = [UNNotificationSound soundNamed:platformSpecifics[SOUND]];
    }
    if ([self containsKey:SUBTITLE forDictionary:platformSpecifics]) {
      content.subtitle = platformSpecifics[SUBTITLE];
    }
    if (@available(iOS 15.0, *)) {
      if ([self containsKey:INTERRUPTION_LEVEL
              forDictionary:platformSpecifics]) {
        NSNumber *interruptionLevel = platformSpecifics[INTERRUPTION_LEVEL];

        if (interruptionLevel != nil) {
          content.interruptionLevel = [interruptionLevel integerValue];
        }
      }
    }
    if ([self containsKey:@"categoryIdentifier"
            forDictionary:platformSpecifics]) {
      content.categoryIdentifier = platformSpecifics[@"categoryIdentifier"];
    }
  }

  if (presentSound && content.sound == nil) {
    content.sound = UNNotificationSound.defaultSound;
  }
  content.userInfo = [self buildUserDict:arguments[ID]
                                   title:content.title
                            presentAlert:presentAlert
                            presentSound:presentSound
                            presentBadge:presentBadge
                                 payload:arguments[PAYLOAD]];
  return content;
}

- (UNCalendarNotificationTrigger *)buildUserNotificationCalendarTrigger:
    (id)arguments NS_AVAILABLE_IOS(10.0) {
  NSString *scheduledDateTime = arguments[SCHEDULED_DATE_TIME];
  NSString *timeZoneName = arguments[TIME_ZONE_NAME];

  NSNumber *matchDateComponents = arguments[MATCH_DATE_TIME_COMPONENTS];
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSTimeZone *timezone = [NSTimeZone timeZoneWithName:timeZoneName];
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

  // Needed for some countries, when phone DateTime format is 12H
  NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];

  [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
  [dateFormatter setTimeZone:timezone];
  [dateFormatter setLocale:posix];

  NSDate *date = [dateFormatter dateFromString:scheduledDateTime];

  calendar.timeZone = timezone;
  if (matchDateComponents != nil) {
    if ([matchDateComponents integerValue] == Time) {
      NSDateComponents *dateComponents =
          [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute |
                                NSCalendarUnitSecond | NSCalendarUnitTimeZone)
                      fromDate:date];
      return [UNCalendarNotificationTrigger
          triggerWithDateMatchingComponents:dateComponents
                                    repeats:YES];

    } else if ([matchDateComponents integerValue] == DayOfWeekAndTime) {
      NSDateComponents *dateComponents =
          [calendar components:(NSCalendarUnitWeekday | NSCalendarUnitHour |
                                NSCalendarUnitMinute | NSCalendarUnitSecond |
                                NSCalendarUnitTimeZone)
                      fromDate:date];
      return [UNCalendarNotificationTrigger
          triggerWithDateMatchingComponents:dateComponents
                                    repeats:YES];
    } else if ([matchDateComponents integerValue] == DayOfMonthAndTime) {
      NSDateComponents *dateComponents =
          [calendar components:(NSCalendarUnitDay | NSCalendarUnitHour |
                                NSCalendarUnitMinute | NSCalendarUnitSecond |
                                NSCalendarUnitTimeZone)
                      fromDate:date];
      return [UNCalendarNotificationTrigger
          triggerWithDateMatchingComponents:dateComponents
                                    repeats:YES];
    } else if ([matchDateComponents integerValue] == DateAndTime) {
      NSDateComponents *dateComponents =
          [calendar components:(NSCalendarUnitMonth | NSCalendarUnitDay |
                                NSCalendarUnitHour | NSCalendarUnitMinute |
                                NSCalendarUnitSecond | NSCalendarUnitTimeZone)
                      fromDate:date];
      return [UNCalendarNotificationTrigger
          triggerWithDateMatchingComponents:dateComponents
                                    repeats:YES];
    }
    return nil;
  }
  NSDateComponents *dateComponents = [calendar
      components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                  NSCalendarUnitHour | NSCalendarUnitMinute |
                  NSCalendarUnitSecond | NSCalendarUnitTimeZone)
        fromDate:date];
  return [UNCalendarNotificationTrigger
      triggerWithDateMatchingComponents:dateComponents
                                repeats:NO];
}

- (UNTimeIntervalNotificationTrigger *)buildUserNotificationTimeIntervalTrigger:
    (id)arguments API_AVAILABLE(ios(10.0)) {
  switch ([arguments[REPEAT_INTERVAL] integerValue]) {
  case EveryMinute:
    return [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:60
                                                              repeats:YES];
  case Hourly:
    return [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:60 * 60
                                                              repeats:YES];
  case Daily:
    return
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:60 * 60 * 24
                                                           repeats:YES];
    break;
  case Weekly:
    return [UNTimeIntervalNotificationTrigger
        triggerWithTimeInterval:60 * 60 * 24 * 7
                        repeats:YES];
  }
  return nil;
}

- (NSDictionary *)buildUserDict:(NSNumber *)id
                          title:(NSString *)title
                   presentAlert:(bool)presentAlert
                   presentSound:(bool)presentSound
                   presentBadge:(bool)presentBadge
                        payload:(NSString *)payload {
  NSMutableDictionary *userDict = [[NSMutableDictionary alloc] init];
  userDict[NOTIFICATION_ID] = id;
  if (title) {
    userDict[TITLE] = title;
  }
  userDict[PRESENT_ALERT] = [NSNumber numberWithBool:presentAlert];
  userDict[PRESENT_SOUND] = [NSNumber numberWithBool:presentSound];
  userDict[PRESENT_BADGE] = [NSNumber numberWithBool:presentBadge];
  userDict[PAYLOAD] = payload;
  return userDict;
}

- (BOOL)isAFlutterLocalNotification:(NSDictionary *)userInfo {
  return userInfo != nil && userInfo[NOTIFICATION_ID] &&
         userInfo[PRESENT_ALERT] && userInfo[PRESENT_SOUND] &&
         userInfo[PRESENT_BADGE] && userInfo[PAYLOAD];
}

- (void)handleSelectNotification:(NSString *)payload {
  [_channel invokeMethod:@"selectNotification" arguments:payload];
}

- (BOOL)containsKey:(NSString *)key forDictionary:(NSDictionary *)dictionary {
  return dictionary[key] != [NSNull null] && dictionary[key] != nil;
}

#pragma mark - UNUserNotificationCenterDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:
             (void (^)(UNNotificationPresentationOptions))completionHandler
    NS_AVAILABLE_IOS(10.0) {
  if (![self
          isAFlutterLocalNotification:notification.request.content.userInfo]) {
    return;
  }
  UNNotificationPresentationOptions presentationOptions = 0;
  NSNumber *presentAlertValue =
      (NSNumber *)notification.request.content.userInfo[PRESENT_ALERT];
  NSNumber *presentSoundValue =
      (NSNumber *)notification.request.content.userInfo[PRESENT_SOUND];
  NSNumber *presentBadgeValue =
      (NSNumber *)notification.request.content.userInfo[PRESENT_BADGE];
  bool presentAlert = [presentAlertValue boolValue];
  bool presentSound = [presentSoundValue boolValue];
  bool presentBadge = [presentBadgeValue boolValue];
  if (presentAlert) {
    presentationOptions |= UNNotificationPresentationOptionAlert;
  }
  if (presentSound) {
    presentationOptions |= UNNotificationPresentationOptionSound;
  }
  if (presentBadge) {
    presentationOptions |= UNNotificationPresentationOptionBadge;
  }
  completionHandler(presentationOptions);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler
    NS_AVAILABLE_IOS(10.0) {
  if (![self isAFlutterLocalNotification:response.notification.request.content
                                             .userInfo]) {
    return;
  }
  if ([response.actionIdentifier
          isEqualToString:UNNotificationDefaultActionIdentifier]) {
    NSString *payload =
        (NSString *)response.notification.request.content.userInfo[PAYLOAD];
    if (_initialized) {
      [self handleSelectNotification:payload];
    } else {
      _launchPayload = payload;
      _launchingAppFromNotification = true;
    }
    completionHandler();
  } else if (response.actionIdentifier != nil) {
    if (!actionEventSink) {
      actionEventSink = [[ActionEventSink alloc] init];
    }

    NSString *text = @"";
    if ([response respondsToSelector:@selector(userText)]) {
      text = [(UNTextInputNotificationResponse *)response userText];
    }

    [actionEventSink addItem:@{
      @"notificationId" : response.notification.request.identifier,
      @"actionId" : response.actionIdentifier,
      @"input" : text,
      @"payload" : response.notification.request.content.userInfo[@"payload"],
    }];

    [_flutterEngineManager startEngineIfNeeded:actionEventSink
                               registerPlugins:registerPlugins];

    completionHandler();
  }
}

@end
