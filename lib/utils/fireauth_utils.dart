// import 'package:cloud_functions/cloud_functions.dart';

// Represents the password policy fetched from Firebase Functions.
// Includes minimum and maximum length, and requirements for character types.
// For example, whether lowercase, uppercase, numeric, and special characters are needed.

class PasswordPolicy {
  final int min, max;
  final bool needLower, needUpper, needNum, needSym;
  const PasswordPolicy({
    required this.min, required this.max,
    required this.needLower, required this.needUpper,
    required this.needNum, required this.needSym,
  });
  factory PasswordPolicy.fromMap(Map m) => PasswordPolicy(
    min: m['min'] ?? 6,
    max: m['max'] ?? 4096,
    needLower: m['needLower'] ?? false,
    needUpper: m['needUpper'] ?? false,
    needNum:   m['needNum']   ?? false,
    needSym:   m['needSym']   ?? false,
  );
}

Future<PasswordPolicy> fetchPasswordPolicy() async {

  // Return a safe default policy if the function call fails.
  return const PasswordPolicy(min: 8, max: 4096, needLower: true, needUpper: true, needNum: true, needSym: true);

  // TODO: Re-enable fetching from Firebase Functions once IAM/ADC issues are resolved.
  // This Firebase Function is not working currently due to
  // Identity and Access Management
  // (IAM) and Application Default Credentials (ADC) issues. See:
  // https://firebase.google.com/docs/functions/callable#call_from_a_client_app

  // Use the default functions instance. Callers can pass a specific region by
  // using `FirebaseFunctions.instanceFor(region: 'us-central1')` if needed.
  // try {
  //   final callable = FirebaseFunctions.instance.httpsCallable('getPasswordPolicyForApp');
  //   final res = await callable.call();
  //   return PasswordPolicy.fromMap(Map<String, dynamic>.from(res.data as Map));
  // } on FirebaseFunctionsException catch (e, st) {
  //   // Common cause: function not deployed, wrong name, or wrong region.
  //   // Return a safe default policy so the app remains usable.
  //   // Log the error so it can be diagnosed.
  //   // You can adjust this to rethrow if you prefer the caller to handle failures.
  //   // Example: e.code == 'not-found'
  //   // See: https://firebase.google.com/docs/functions/callable#handle_errors
  //   // Print minimal diagnostics for local debugging.
  //   // ignore: avoid_print
  //   print('FirebaseFunctionsException while fetching password policy: ${e.code} ${e.message}\n$st');

  //   // Return a safe default policy if the function call fails.
  //   return const PasswordPolicy(min: 6, max: 4096, needLower: true, needUpper: true, needNum: true, needSym: true);
  // } catch (e, st) {
  //   // Fallback for any other unexpected errors.
  //   // ignore: avoid_print
  //   print('Unexpected error fetching password policy: $e\n$st');
  //   return const PasswordPolicy(min: 6, max: 4096, needLower: false, needUpper: false, needNum: false, needSym: false);
  // }
}
