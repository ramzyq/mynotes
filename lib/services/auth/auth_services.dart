import 'package:mynotes/services/auth/auth_user.dart';
import 'package:mynotes/services/auth/auth_provider.dart';

class AuthService implements AuthProvider {
  final AuthProvider provider;

  const AuthService(this.provider);
  
  @override
  Future<AuthUser> createUser({required Pattern email, required String password}) {
    
  }
  
  @override
  
  AuthUser? get currentUser => throw UnimplementedError();
  
  @override
  Future<AuthUser> logIn({required String email, required String password}) {
   
    
  }
  
  @override
  Future<void> logOut() {
    
    
  }
  
  @override
  Future<void> sendEmailVerification() {
    
    
  }

 
}
