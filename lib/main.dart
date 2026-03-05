import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mynotes/views/login_view.dart';
import 'package:mynotes/firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp( MaterialApp(
      title: 'Aktif - the student partner',
      theme: ThemeData(
        
        colorScheme: .fromSeed(seedColor: const Color.fromARGB(255, 8, 172, 93)),
      ),
      home: const LoginView(),
    ),);
}
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();// TO: implement initState
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  } 
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),),
      body: FutureBuilder(
        future: Firebase.initializeApp(
                  options: DefaultFirebaseOptions.currentPlatform
                ),
        builder: (context, snapshot) {
          switch (snapshot.connectionState){
            
            
            case ConnectionState.done:
              return Column(
          children: [
            TextField(
              controller: _email,
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: "Enter your email" ,
              ), 
            ),
            TextField(
              controller: _password,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false, 
              decoration: const InputDecoration(
                hintText: "Enter your password" ,
              ),
            ),
            TextButton(
              onPressed: () async {
              final email = _email.text.trim();
              final password = _password.text.trim();

              if (email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email and password cannot be empty')),
                );
                return;
              }

              try {
                    await FirebaseAuth.instance.setLanguageCode('en');
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: email,
                    password: password,
                    );
                     } on FirebaseAuthException catch (e) {
                       print(e.code);
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Registration failed: ${e.message}')),
                       );
                   }
          },
            child: const Text("Register"),
)       
              
          ],
        ); 
        default: 
        return const Text("Loading...");
            
          }
          
        },
        
      ),
    );
  }
}