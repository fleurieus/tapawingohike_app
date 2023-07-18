import 'package:flutter/material.dart';

import 'package:tapa_hike/services/socket.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Authenticatie'),
      ),
      body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
          child: TextFormField(
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
              labelText: 'Voer hier je TEAM ID in...',
            ),
            onFieldSubmitted: (authStr) {
              socketConnection.authenticate(authStr);
              Navigator.pushReplacementNamed(context, "/hike");
            },
          ),
        ),
    );
  }
}