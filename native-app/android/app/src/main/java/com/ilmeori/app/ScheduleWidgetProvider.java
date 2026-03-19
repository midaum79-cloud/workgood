package com.ilmeori.app;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class ScheduleWidgetProvider extends AppWidgetProvider {

    private static final String TAG = "일머리Widget";
    private static final String API_URL = "https://ilmeori.onrender.com/api/widget/schedule";
    private static final String PREFS_NAME = "ilmeori_widget";
    private static final String KEY_TOKEN = "widget_token";

    private static final int[] TODAY_ITEM_IDS = {
        R.id.widget_today_item1,
        R.id.widget_today_item2,
        R.id.widget_today_item3
    };

    private static final int[] TOMORROW_ITEM_IDS = {
        R.id.widget_tomorrow_item1,
        R.id.widget_tomorrow_item2,
        R.id.widget_tomorrow_item3
    };

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId);
        }
    }

    private void updateWidget(Context context, AppWidgetManager appWidgetManager, int widgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_schedule);

        // 위젯 클릭 시 앱 열기
        Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launchIntent != null) {
            PendingIntent pendingIntent = PendingIntent.getActivity(
                context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent);
        }

        // 로딩 상태 표시
        views.setTextViewText(R.id.widget_date, "📅 로딩 중...");
        appWidgetManager.updateAppWidget(widgetId, views);

        // 백그라운드에서 데이터 로드
        ExecutorService executor = Executors.newSingleThreadExecutor();
        Handler handler = new Handler(Looper.getMainLooper());

        executor.execute(() -> {
            try {
                String token = getWidgetToken(context);
                String jsonStr = fetchSchedule(token);

                handler.post(() -> {
                    try {
                        if (jsonStr != null) {
                            JSONObject json = new JSONObject(jsonStr);
                            renderSchedule(context, views, json);
                        } else {
                            views.setTextViewText(R.id.widget_date, "📅 로그인이 필요합니다");
                            views.setTextViewText(R.id.widget_today_empty, "앱에서 로그인해주세요");
                            views.setViewVisibility(R.id.widget_today_empty, View.VISIBLE);
                            views.setTextViewText(R.id.widget_tomorrow_empty, "");
                        }
                        appWidgetManager.updateAppWidget(widgetId, views);
                    } catch (Exception e) {
                        Log.e(TAG, "Render error", e);
                    }
                });
            } catch (Exception e) {
                Log.e(TAG, "Fetch error", e);
                handler.post(() -> {
                    views.setTextViewText(R.id.widget_date, "📅 연결 오류");
                    views.setTextViewText(R.id.widget_today_empty, "네트워크를 확인해주세요");
                    views.setViewVisibility(R.id.widget_today_empty, View.VISIBLE);
                    appWidgetManager.updateAppWidget(widgetId, views);
                });
            }
        });
    }

    private void renderSchedule(Context context, RemoteViews views, JSONObject json) throws Exception {
        String date = json.optString("date", "");
        String dayName = json.optString("day_name", "");

        // 날짜 파싱
        if (!date.isEmpty()) {
            String[] parts = date.split("-");
            String dateText = "📅 " + Integer.parseInt(parts[1]) + "월 " + Integer.parseInt(parts[2]) + "일 (" + dayName + ")";
            views.setTextViewText(R.id.widget_date, dateText);
        }

        // 오늘 일정
        JSONArray today = json.optJSONArray("today");
        if (today != null && today.length() > 0) {
            views.setViewVisibility(R.id.widget_today_empty, View.GONE);
            for (int i = 0; i < Math.min(today.length(), TODAY_ITEM_IDS.length); i++) {
                JSONObject item = today.getJSONObject(i);
                String text = "● " + item.getString("process") + " — " + item.getString("project");
                views.setTextViewText(TODAY_ITEM_IDS[i], text);
                views.setViewVisibility(TODAY_ITEM_IDS[i], View.VISIBLE);
            }
            // 숨기기: 사용하지 않는 아이템
            for (int i = today.length(); i < TODAY_ITEM_IDS.length; i++) {
                views.setViewVisibility(TODAY_ITEM_IDS[i], View.GONE);
            }
        } else {
            views.setViewVisibility(R.id.widget_today_empty, View.VISIBLE);
            views.setTextViewText(R.id.widget_today_empty, "오늘 일정이 없습니다 ☀️");
            for (int id : TODAY_ITEM_IDS) {
                views.setViewVisibility(id, View.GONE);
            }
        }

        // 내일 일정
        JSONArray tomorrow = json.optJSONArray("tomorrow");
        if (tomorrow != null && tomorrow.length() > 0) {
            views.setViewVisibility(R.id.widget_tomorrow_empty, View.GONE);
            for (int i = 0; i < Math.min(tomorrow.length(), TOMORROW_ITEM_IDS.length); i++) {
                JSONObject item = tomorrow.getJSONObject(i);
                String text = "● " + item.getString("process") + " — " + item.getString("project");
                views.setTextViewText(TOMORROW_ITEM_IDS[i], text);
                views.setViewVisibility(TOMORROW_ITEM_IDS[i], View.VISIBLE);
            }
            for (int i = tomorrow.length(); i < TOMORROW_ITEM_IDS.length; i++) {
                views.setViewVisibility(TOMORROW_ITEM_IDS[i], View.GONE);
            }
        } else {
            views.setViewVisibility(R.id.widget_tomorrow_empty, View.VISIBLE);
            views.setTextViewText(R.id.widget_tomorrow_empty, "내일 일정이 없습니다");
            for (int id : TOMORROW_ITEM_IDS) {
                views.setViewVisibility(id, View.GONE);
            }
        }
    }

    private String getWidgetToken(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getString(KEY_TOKEN, null);
    }

    public static void saveWidgetToken(Context context, String token) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putString(KEY_TOKEN, token).apply();

        // 토큰 저장 후 위젯 즉시 업데이트
        AppWidgetManager mgr = AppWidgetManager.getInstance(context);
        int[] ids = mgr.getAppWidgetIds(new ComponentName(context, ScheduleWidgetProvider.class));
        if (ids.length > 0) {
            Intent intent = new Intent(context, ScheduleWidgetProvider.class);
            intent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids);
            context.sendBroadcast(intent);
        }
    }

    private String fetchSchedule(String token) {
        if (token == null || token.isEmpty()) return null;

        try {
            URL url = new URL(API_URL);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("Authorization", "Bearer " + token);
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
                return sb.toString();
            } else {
                Log.w(TAG, "API returned " + responseCode);
                return null;
            }
        } catch (Exception e) {
            Log.e(TAG, "Network error", e);
            return null;
        }
    }
}
