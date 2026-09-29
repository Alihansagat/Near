import React, { useRef, useState } from 'react';
import { ActivityIndicator, Linking, Pressable, StyleSheet, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { WebView } from 'react-native-webview';

const APP_URL = 'https://alihansagat.github.io/Near/?preview=expo-v2';

export default function App() {
  const web = useRef(null);
  const [failed, setFailed] = useState(false);
  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.page} edges={['top', 'bottom']}>
        <StatusBar style="dark" />
        <View style={styles.toolbar}>
          <Text style={styles.brand}>near</Text>
          <View style={styles.actions}>
            <Pressable accessibilityRole="button" accessibilityLabel="Open Near in Safari" onPress={() => Linking.openURL(APP_URL)} style={styles.button}><Text style={styles.label}>Safari ↗</Text></Pressable>
            <Pressable accessibilityRole="button" accessibilityLabel="Reload Near" onPress={() => { setFailed(false); web.current?.reload(); }} style={styles.button}><Text style={styles.label}>↻</Text></Pressable>
          </View>
        </View>
        {failed ? <View style={styles.center}>
          <Text style={styles.title}>Let’s reconnect</Text>
          <Text style={styles.message}>Check your connection, then try again.</Text>
          <Pressable style={styles.retry} onPress={() => setFailed(false)}><Text style={styles.retryText}>Try again</Text></Pressable>
        </View> : <WebView
          ref={web}
          source={{ uri: APP_URL }}
          style={styles.web}
          javaScriptEnabled
          domStorageEnabled
          sharedCookiesEnabled
          allowsInlineMediaPlayback
          mediaPlaybackRequiresUserAction
          startInLoadingState
          renderLoading={() => <View style={[StyleSheet.absoluteFill, styles.center]}><ActivityIndicator color="#965468" /><Text style={styles.message}>Opening our space…</Text></View>}
          onError={() => setFailed(true)}
          onHttpError={(event) => { if (event.nativeEvent.url.startsWith(APP_URL.split('?')[0]) && event.nativeEvent.statusCode >= 500) setFailed(true); }}
          onContentProcessDidTerminate={() => web.current?.reload()}
          onShouldStartLoadWithRequest={(request) => {
            // Subframes and same-origin routes stay inside Near. External pages open in Safari.
            if (request.isTopFrame === false || request.url.startsWith('https://alihansagat.github.io/Near/') || request.url === 'about:blank' || request.url.startsWith('blob:')) return true;
            if (request.url.startsWith('https://')) Linking.openURL(request.url);
            return false;
          }}
        />}
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  page: { flex: 1, backgroundColor: '#F7F6F3' },
  web: { flex: 1, backgroundColor: '#F7F6F3' },
  toolbar: { height: 44, paddingHorizontal: 18, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  brand: { fontSize: 23, fontWeight: '700', letterSpacing: -1, color: '#965468' },
  actions: { flexDirection: 'row', gap: 8 },
  button: { paddingHorizontal: 10, minHeight: 44, justifyContent: 'center' },
  label: { fontSize: 14, color: '#777880', fontWeight: '500' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#F7F6F3', padding: 28 },
  title: { fontSize: 23, fontWeight: '600', color: '#292D35' },
  message: { marginTop: 14, color: '#777880', textAlign: 'center', lineHeight: 22 },
  retry: { marginTop: 24, paddingVertical: 14, paddingHorizontal: 24, backgroundColor: '#965468', borderRadius: 16 },
  retryText: { color: '#fff', fontWeight: '600' },
});
