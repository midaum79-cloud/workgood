package com.ilmeori.app;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.webkit.CookieManager;
import android.webkit.WebView;

import com.getcapacitor.BridgeActivity;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends BridgeActivity {

    private static final String TAG = "일머리";
    private static final String SERVER_URL = "https://ilmeori.onrender.com";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // 앱이 처음 시작될 때 deep link 확인
        handleDeepLink(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        // 앱이 이미 실행 중일 때 deep link 수신
        handleDeepLink(intent);
    }

    @Override
    public void onResume() {
        super.onResume();
        // 앱이 포그라운드로 올 때마다 위젯 토큰 갱신 시도
        fetchAndSaveWidgetToken();
    }

    private void handleDeepLink(Intent intent) {
        if (intent == null) return;
        Uri uri = intent.getData();
        if (uri != null && "ilmeori".equals(uri.getScheme())) {
            String token = uri.getQueryParameter("token");
            Log.d(TAG, "Deep link received: " + uri.toString());
            if (token != null && !token.isEmpty()) {
                Log.d(TAG, "Token found, loading token_login...");
                String loginUrl = SERVER_URL + "/auth/token_login?token=" + token;
                getBridge().getWebView().post(() -> {
                    getBridge().getWebView().loadUrl(loginUrl);
                });
            }
        }
    }

    /**
     * 서버에서 위젯 전용 토큰을 발급받아 SharedPreferences에 저장.
     * 쿠키 기반으로 인증하므로 로그인 상태에서만 동작.
     */
    private void fetchAndSaveWidgetToken() {
        ExecutorService executor = Executors.newSingleThreadExecutor();
        executor.execute(() -> {
            try {
                // WebView의 세션 쿠키 가져오기
                String cookies = CookieManager.getInstance().getCookie(SERVER_URL);
                if (cookies == null || cookies.isEmpty()) {
                    Log.d(TAG, "No cookies, skip widget token fetch");
                    return;
                }

                URL url = new URL(SERVER_URL + "/api/widget/token");
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Cookie", cookies);
                conn.setRequestProperty("Accept", "application/json");
                conn.setConnectTimeout(10000);
                conn.setReadTimeout(10000);

                int responseCode = conn.getResponseCode();
                if (responseCode == 200) {
                    BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                    StringBuilder sb = new StringBuilder();
                    String line;
                    while ((line = reader.readLine()) != null) {
                        sb.append(line);
                    }
                    reader.close();

                    // JSON에서 토큰 추출
                    String json = sb.toString();
                    // 간단한 파싱: {"token":"xxx"}
                    int start = json.indexOf("\"token\":\"") + 9;
                    int end = json.indexOf("\"", start);
                    if (start > 8 && end > start) {
                        String widgetToken = json.substring(start, end);
                        ScheduleWidgetProvider.saveWidgetToken(this, widgetToken);
                        Log.d(TAG, "Widget token saved");
                    }
                } else {
                    Log.d(TAG, "Widget token API returned " + responseCode);
                }
            } catch (Exception e) {
                Log.e(TAG, "Widget token fetch error", e);
            }
        });
    }
}
