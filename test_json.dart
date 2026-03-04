import 'dart:convert';

void main() {
  try {
    json.decode("'{\n  \"type\": \"service_account\"\n}'");
  } catch (e) {
    print('Test 1: $e');
  }

  try {
    json.decode("{\n  'type': 'service_account'\n}");
  } catch (e) {
    print('Test 2: $e');
  }
}
