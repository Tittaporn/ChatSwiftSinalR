//
//  ViewController.swift
//  SwiftSignalRClientDemo
//
//  Created by M3ts LLC on 11/15/21.
//

import UIKit
import SwiftSignalRClient

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    // MARK: - Properties
    private let serverUrl = "https://leetestserver.azurewebsites.net/chat" //"http://192.168.86.115:5000/chat" // /chat or /chatLongPolling or /chatWebSockets
    private let dispatchQueue = DispatchQueue(label: "hubsamplephone.queue.dispatcheueuq")
    private var chatHubConnection: HubConnection?
    private var chatHubConnectionDelegate: HubConnectionDelegate?
    private var name = ""
    private var messages: [String] = []
    private var reconnectAlert: UIAlertController?

    // MARK: - Outlets
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var chatTableView: UITableView!
    @IBOutlet weak var msgTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        msgTextField.addDoneButtonToKeyboard(myAction:  #selector(self.msgTextField.resignFirstResponder))
        self.chatTableView.delegate = self
        self.chatTableView.dataSource = self
    }

    override func viewDidAppear(_ animated: Bool) {
        let alert = UIAlertController(title: "Enter your Name", message:"", preferredStyle: UIAlertController.Style.alert)
        alert.addTextField() { textField in textField.placeholder = "Name"}
        let OKAction = UIAlertAction(title: "OK", style: .default) { action in
            self.name = alert.textFields?.first?.text ?? "John Doe"

            self.chatHubConnectionDelegate = ChatHubConnectionDelegate(controller: self)
            self.chatHubConnection = HubConnectionBuilder(url: URL(string: self.serverUrl)!)
                .withLogging(minLogLevel: .debug)
                .withAutoReconnect()
                .withHubConnectionDelegate(delegate: self.chatHubConnectionDelegate!)
                .build()

            self.chatHubConnection!.on(method: "NewMessage", callback: {(user: String, message: String) in
                self.appendMessage(message: "\(user): \(message)")
                print("\n\n+++++++++++ TEST user =>  :user \(user) == message \(message) +++++++++++ AT LINE : \(#line) +++ OF \(#function) +++ IN \(#file) +++++++++++\n\n")
            })
            self.chatHubConnection!.start()
        }
        alert.addAction(OKAction)
        self.present(alert, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        chatHubConnection?.stop()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func btnSend(_ sender: Any) {
        let message = msgTextField.text
        if message != "" {
            chatHubConnection?.invoke(method: "Broadcast", name, message) { error in
                if let e = error {
                    self.appendMessage(message: "Error: \(e)")
                }
            }
            msgTextField.text = ""
        }
    }

    private func appendMessage(message: String) {
        self.dispatchQueue.sync {
            self.messages.append(message)
        }
        self.chatTableView.beginUpdates()
        self.chatTableView.insertRows(at: [IndexPath(row: messages.count - 1, section: 0)], with: .automatic)
        self.chatTableView.endUpdates()
        self.chatTableView.scrollToRow(at: IndexPath(item: messages.count-1, section: 0), at: .bottom, animated: true)
    }

    fileprivate func connectionDidOpen() {
        print("\n\n+++++++++++ TEST  =>  :connectionDidOpen \(String(describing: connectionDidOpen)) +++++++++++ AT LINE : \(#line) +++ OF \(#function) +++ IN \(#file) +++++++++++\n\n")
        toggleUI(isEnabled: true)
    }

    fileprivate func connectionDidFailToOpen(error: Error) {
        blockUI(message: "Connection failed to start.", error: error)
    }

    fileprivate func connectionDidClose(error: Error?) {
        if let alert = reconnectAlert {
            alert.dismiss(animated: true, completion: nil)
        }
        blockUI(message: "Connection is closed.", error: error)
    }

    fileprivate func connectionWillReconnect(error: Error?) {
        guard reconnectAlert == nil else {
            print("Alert already present. This is unexpected.")
            return
        }

        reconnectAlert = UIAlertController(title: "Reconnecting...", message: "Please wait", preferredStyle: .alert)
        self.present(reconnectAlert!, animated: true, completion: nil)
    }

    fileprivate func connectionDidReconnect() {
        reconnectAlert?.dismiss(animated: true, completion: nil)
        reconnectAlert = nil
    }

    func blockUI(message: String, error: Error?) {
        var message = message
        if let e = error {
            message.append(" Error: \(e)")
        }
        appendMessage(message: message)
        toggleUI(isEnabled: false)
    }

    func toggleUI(isEnabled: Bool) {
        sendButton.isEnabled = isEnabled
        msgTextField.isEnabled = isEnabled
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = -1
        dispatchQueue.sync {
            count = self.messages.count
        }
        return count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath)
        let row = indexPath.row
        cell.textLabel?.text = messages[row]
        return cell
    }
}

class ChatHubConnectionDelegate: HubConnectionDelegate {

    weak var controller: ViewController?
    var connectionId: String?

    init(controller: ViewController) {
        self.controller = controller
    }

    func connectionDidOpen(hubConnection: HubConnection) {
        connectionId = hubConnection.connectionId
        print("\n\n+++++++++++ TEST  => connectionId : \(connectionId) +++++++++++ AT LINE : \(#line) +++ OF \(#function) +++ IN \(#file) +++++++++++\n\n")
        controller?.connectionDidOpen()
    }

    func connectionDidFailToOpen(error: Error) {
        controller?.connectionDidFailToOpen(error: error)
    }

    func connectionDidClose(error: Error?) {
        controller?.connectionDidClose(error: error)
    }

    func connectionWillReconnect(error: Error) {
        controller?.connectionWillReconnect(error: error)
    }

    func connectionDidReconnect() {
        controller?.connectionDidReconnect()
    }
}

// MARK: - UITextField
extension UITextField {
    func addDoneButtonToKeyboard(myAction:Selector?){
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        doneToolbar.barStyle = UIBarStyle.default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.done, target: self, action: myAction)
        
        var items = [UIBarButtonItem]()
        items.append(flexSpace)
        items.append(done)
        
        doneToolbar.items = items
        doneToolbar.sizeToFit()
        
        self.inputAccessoryView = doneToolbar
    }
}
