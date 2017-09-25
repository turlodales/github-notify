import Cocoa
import OAuth2

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var github: GithubLoader!
    var unreadCount = 0
    let statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Register our URL scheme.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(AppDelegate.handleGetURL(event:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))

        self.unreadCount = 0

        // Pull Github OAuth credentials
        guard let infoPlist = Bundle.main.infoDictionary,
            let clientId = infoPlist["GITHUB_OAUTH_CLIENT_ID"] as? String,
            let clientSecret = infoPlist["GITHUB_OAUTH_CLIENT_SECRET"] as? String else {
                print("Missing GitHub credentials in Info.plist!")
                return
        }

        self.github = GithubLoader(clientId: clientId, clientSecret: clientSecret)
        self.github.attemptToAuthorize(callback: { _, error in
            if error != nil {
                NSAlert(error: error!).runModal()
                NSApp.terminate(self)
            } else {
                self.refreshNotifications(nil)
            }
        })

        self.updateMenubarIcon()
        self.buildIconMenu()

        // Refresh the unread notification count.
        Timer.scheduledTimer(timeInterval: 60.0,
                             target: self,
                             selector: #selector(AppDelegate.refreshNotifications),
                             userInfo: nil,
                             repeats: true)
    }

    @objc
    func openNotificationUrl(_ sender: Any?) {
        NSWorkspace.shared().open(URL(string: "https://github.com/notifications")!)
    }

    func buildIconMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Refresh notifications", action: #selector(AppDelegate.refreshNotifications(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open in browser", action: #selector(AppDelegate.openNotificationUrl(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit GithubNotify", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }

    func updateMenubarIcon() {
        let icon : String
        if self.unreadCount > 0 {
            icon = "MenuIconUnread"
        } else {
            icon = "MenuIconDefault"
        }

        if let button = statusItem.button {
            button.toolTip = "\(self.unreadCount) unread notifications."
            button.image = NSImage(named: icon)
            button.action = #selector(openNotificationUrl(_:))
        }
    }

    @objc
    func refreshNotifications(_ sender: Any?) {
        self.github.refreshNotifications() { notifications, error in
            if let error = error {
                NSAlert(error: error).runModal()
                return
            }

            self.unreadCount = notifications!.count
            self.updateMenubarIcon()
        }
    }

    func handleGetURL(event: NSAppleEventDescriptor!, withReplyEvent: NSAppleEventDescriptor!) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
            let url = URL(string: urlString)  {

            if url.scheme == "github-notify" {
                do {
                    try self.github.oauth2.handleRedirectURL(url)
                } catch let error {
                    NSAlert(error: error).runModal()
                }
            }

        }
    }
}

