import UIKit

class StoryboardiOSViewController: UIViewController {
    // MARK: - Outlets
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    // @IBOutlet weak var passwordLabel: UILabel!
    // @IBOutlet weak var passwordTextField: UITextField!
    // @IBOutlet weak var loginButton: UIButton!

    // MARK: - Actions
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        // Example login validation logic (add your own as needed)
        // let name = nameTextField.text ?? ""
        // let password = passwordTextField.text ?? ""
        // if name.isEmpty || password.isEmpty {
        //     // Present an alert or show an error
        //     let alert = UIAlertController(title: "Missing Info", message: "Please enter both name and password.", preferredStyle: .alert)
        //     alert.addAction(UIAlertAction(title: "OK", style: .default))
        //     present(alert, animated: true)
        //     return
        // }
        // Perform login logic here
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }
}
