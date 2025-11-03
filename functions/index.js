/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
// Use the official firebase-admin SDK to access admin.initializeApp().
// The previous code attempted to read `admin` from `firebase-functions/https`
// which does not export an `admin` object (causing initializeApp
// to be undefined).
const admin = require("firebase-admin");
const {GoogleAuth} = require("google-auth-library");
// const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
// Apply global options using the functions namespace
functions.setGlobalOptions({maxInstances: 10});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

admin.initializeApp();

exports.getPasswordPolicyForApp = functions.https.onCall(
    async (_data, context) => {
      // NOTE: Previously we enforced that callers must be authenticated
      // (i.e. `context.auth` existed) and would throw `permission-denied` if
      // not. For client-side apps that need to read the password policy before
      // signing in (for example to render password requirements on a signup
      // form), the policy should be readable by unauthenticated callers.
      //
      // If this policy contains sensitive admin-only configuration, re-enable
      // the check and require callers to be authenticated and/or have an
      // `admin` custom claim.
      // Optional: require admin callers only
      // if (!context.auth /* || context.auth.token.admin !== true */) {
      //   throw new functions.https.HttpsError(
      //       "permission-denied", "Auth required",
      //   );
      // }

      const auth = new GoogleAuth({
        scopes: ["https://www.googleapis.com/auth/cloud-platform"],
      });
      const client = await auth.getClient();
      const tokenResponse = await client.getAccessToken();
      const token = tokenResponse?.token;
      console.log("PasswordPolicy: got access token?", !!token);

      // TODO: This requires OAuth access to the Identity Toolkit API.
      // Forgetting about this for now and we'll just return a safe default.

      // Unhandled error GaxiosError: Request is missing required authentication
      // credential. Expected OAuth 2 access token, login cookie or other valid
      // authentication credential.
      // See https://developers.google.com/identity/sign-in/web/devconsole-project.

      // Call the Identity Toolkit API to get the password policy
      // for the Firebase project associated with the service account.
      const url = "https://identitytoolkit.googleapis.com/v2/passwordPolicy";
      let res;
      try {
        if (!token) {
          console.warn("No ADC access token; returning default policy");

          // This safe default is ignored and handled in the
          // `utils/fetchPasswordPolicy.dart` instead.
          throw new Error("No access token available from ADC");
          // Return a safe default policy so clients can continue.
          //   return {
          //     min: 6,
          //     max: 4096,
          //     needLower: false,
          //     needUpper: false,
          //     needNum: false,
          //     needSym: false,
          //     enforce: null,
          //   };
        }

        res = await client.request({
          url,
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });
      } catch (err) {
        // Log detailed diagnostics to help debugging IAM/ADC issues.
        console.error("Error requesting Identity Toolkit passwordPolicy:", err);
        if (err && err.response && err.response.data) {
          console.error("Response data:", JSON.stringify(err.response.data));
        }

        // This safe default is ignored and handled in the
        // `utils/fetchPasswordPolicy.dart` instead.
        throw new Error("Identity Toolkit passwordPolicy request failed");
        // On error, return a safe default so UI remains usable.
        // return {
        //   min: 6,
        //   max: 4096,
        //   needLower: false,
        //   needUpper: false,
        //   needNum: false,
        //   needSym: false,
        //   enforce: null,
        // };
      }
      // Return only the parts your app needs
      const p = res.data || {};
      return {
        min: p.customStrengthOptions?.minPasswordLength ?? 6,
        max: p.customStrengthOptions?.maxPasswordLength ?? 4096,
        needLower: !!p.customStrengthOptions?.containsLowercaseCharacter,
        needUpper: !!p.customStrengthOptions?.containsUppercaseCharacter,
        needNum: !!p.customStrengthOptions?.containsNumericCharacter,
        needSym: !!p.customStrengthOptions?.containsNonAlphanumericCharacter,
        enforce: p.enforcementState,
      };
    },
);
