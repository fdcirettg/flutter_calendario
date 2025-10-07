import 'package:flutter/material.dart';
import '../services/transparent_google_auth.dart';

class AuthStatusWidget extends StatefulWidget {
  const AuthStatusWidget({Key? key}) : super(key: key);

  @override
  State<AuthStatusWidget> createState() => _AuthStatusWidgetState();
}

class _AuthStatusWidgetState extends State<AuthStatusWidget> {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    final user = TransparentGoogleAuthService.currentUser;
    setState(() {
      _isAuthenticated = TransparentGoogleAuthService.isSignedIn;
      _userEmail = user?.email;
      _userName = user?.displayName;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber,
              size: 16,
              color: Colors.orange.shade700,
            ),
            SizedBox(width: 4),
            Text(
              'No autenticado',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user,
            size: 16,
            color: Colors.green.shade700,
          ),
          SizedBox(width: 4),
          Text(
            _userName ?? _userEmail ?? 'Autenticado',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}