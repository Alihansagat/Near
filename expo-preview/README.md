# Near — Expo Go preview

This is a React Native WebView preview of the existing Flutter web app. It is not a native Flutter binary or a TestFlight build. Both iPhones can open it in Expo Go without paid Apple Developer membership or an email tester list. Each person still signs in to their existing Near account.

```sh
npm ci
npm run preview
```

Scan the printed QR code using the iPhone camera and open it in Expo Go. The tunnel works outside your Wi-Fi network while this computer, its internet connection, and the development server remain running. Restarting the tunnel may change the QR link. This is a development preview, not a permanent standalone installation.

The Safari button is available for browser-only actions such as importing calendar files. Photo/library permissions and geolocation inside Expo Go should be checked on each physical iPhone. A WebView cannot remove Render's free-tier cold starts.

`npm run export:ios` validates the iOS JavaScript bundle; it does not produce a signed IPA. No Apple credentials, tokens, passwords, or tester emails are included in this repository.
