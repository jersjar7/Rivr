import UIKit
import Flutter
import MapboxMaps
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Configure Firebase
    FirebaseApp.configure()
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let tokenChannel = FlutterMethodChannel(name: "com.byuhydroinformaticslab.rivr.mapbox/token", binaryMessenger: controller.binaryMessenger)
    
    tokenChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getMapboxToken" {
        if let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String {
          result(token)
        } else {
          result(FlutterError(code: "NO_TOKEN", message: "No MapBox token found", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    // Configure push notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Push Notification Handlers
  
  override func application(_ application: UIApplication, 
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("📱 APNS token registered successfully")
    Messaging.messaging().apnsToken = deviceToken
  }
  
  override func application(_ application: UIApplication, 
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
  }
  
  // Handle notification when app is in foreground
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification,
                                     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("📨 Foreground notification received: \(userInfo)")
    
    // Show notification even when app is in foreground
    completionHandler([[.alert, .sound, .badge]])
  }
  
  // Handle notification tap
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     didReceive response: UNNotificationResponse,
                                     withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("👆 Notification tapped: \(userInfo)")
    
    completionHandler()
  }
}