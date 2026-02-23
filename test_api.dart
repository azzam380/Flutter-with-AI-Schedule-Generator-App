import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

void main() async {
  final googleSignIn = GoogleSignIn.instance;
  await googleSignIn.initialize(
    clientId: 'YOUR_CLIENT_ID.apps.googleusercontent.com',
  );
  final auth = await googleSignIn.authorizationClient.authorizeScopes([
    'email',
  ]);
  // auth tidak bisa null menurut analyzer
  print(auth.accessToken);
}
