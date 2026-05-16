// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

const Symbol _suppressKey = #dartastic_otel_libs_bugsnag_suppress;

bool bugsnagBridgeSuppressed() {
  return Zone.current[_suppressKey] == true;
}

T runWithoutBugsnagBridge<T>(T Function() body) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}

Future<T> runWithoutBugsnagBridgeAsync<T>(Future<T> Function() body) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}
