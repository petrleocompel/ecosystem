// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Fetches a short-lived GitHub Actions OIDC token with audience
/// `https://pub.dev`.
///
/// Returns the JWT string when running inside a GitHub Actions workflow with
/// `id-token: write` permission, or `null` if OIDC is unavailable.
///
/// The returned token can be passed as the `PUB_TOKEN` environment variable
/// to `dart pub token add https://pub.dev --env-var PUB_TOKEN` and to
/// subsequent `flutter pub publish` invocations so they authenticate
/// non-interactively.
Future<String?> fetchOidcPubToken(http.Client client) async {
  final requestUrl = Platform.environment['ACTIONS_ID_TOKEN_REQUEST_URL'];
  final requestToken = Platform.environment['ACTIONS_ID_TOKEN_REQUEST_TOKEN'];

  if (requestUrl == null || requestToken == null) {
    print(
      'GitHub Actions OIDC environment variables not set; '
      'skipping automated credential setup.',
    );
    return null;
  }

  final uri = Uri.parse(requestUrl);
  final oidcUri = uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'audience': 'https://pub.dev',
    },
  );

  final http.Response response;
  try {
    response = await client.get(
      oidcUri,
      headers: {'Authorization': 'Bearer $requestToken'},
    );
  } catch (e) {
    stderr.writeln('Warning: failed to fetch GitHub OIDC token: $e');
    return null;
  }

  if (response.statusCode != 200) {
    stderr.writeln(
      'Warning: failed to fetch GitHub OIDC token '
      '(HTTP ${response.statusCode}).',
    );
    return null;
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return json['value'] as String?;
}
