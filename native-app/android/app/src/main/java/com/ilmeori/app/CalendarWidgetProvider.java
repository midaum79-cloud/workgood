package com.ilmeori.app;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class CalendarWidgetProvider extends AppWidgetProvider {

    private static final String TAG = "일머리Calendar";
    private static final String API_URL = "https://ilmeori.onrender.com/api/widget/calendar";
    private static final String PREFS_NAME = "ilmeori_widget";
    private static final String CAL_PREFS = "ilmeori_calendar_widget";
    private static final String KEY_TOKEN = "widget_token";

    public static final String ACTION_PREV_MONTH = "com.ilmeori.app.PREV_MONTH";
    public static final String ACTION_NEXT_MONTH = "com.ilmeori.app.NEXT_MONTH";
    public static final String ACTION_TODAY = "com.ilmeori.app.TODAY";
    public static final String ACTION_DATE_CLICK = "com.ilmeori.app.DATE_CLICK";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId);
        }
    }

    @Override
    public void onAppWidgetOptionsChanged(Context context, AppWidgetManager appWidgetManager, int appWidgetId, Bundle newOptions) {
        updateWidget(context, appWidgetManager, appWidgetId);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        String action = intent.getAction();
        if (action == null) return;

        SharedPreferences cal = context.getSharedPreferences(CAL_PREFS, Context.MODE_PRIVATE);

        switch (action) {
            case ACTION_PREV_MONTH: {
                int year = cal.getInt("display_year", Calendar.getInstance().get(Calendar.YEAR));
                int month = cal.getInt("display_month", Calendar.getInstance().get(Calendar.MONTH) + 1);
                month--;
                if (month < 1) { month = 12; year--; }
                cal.edit().putInt("display_year", year).putInt("display_month", month).apply();
                refreshAllWidgets(context);
                break;
            }
            case ACTION_NEXT_MONTH: {
                int year = cal.getInt("display_year", Calendar.getInstance().get(Calendar.YEAR));
                int month = cal.getInt("display_month", Calendar.getInstance().get(Calendar.MONTH) + 1);
                month++;
                if (month > 12) { month = 1; year++; }
                cal.edit().putInt("display_year", year).putInt("display_month", month).apply();
                refreshAllWidgets(context);
                break;
            }
            case ACTION_TODAY: {
                Calendar now = Calendar.getInstance();
                cal.edit()
                    .putInt("display_year", now.get(Calendar.YEAR))
                    .putInt("display_month", now.get(Calendar.MONTH) + 1)
                    .apply();
                refreshAllWidgets(context);
                break;
            }
            case ACTION_DATE_CLICK: {
                String date = intent.getStringExtra("selected_date");
                if (date != null) {
                    // 앱의 캘린더 페이지를 해당 날짜로 열기
                    Intent appIntent = new Intent(Intent.ACTION_VIEW);
                    appIntent.setData(Uri.parse("https://ilmeori.onrender.com/projects/calendar?selected_date=" + date));
                    appIntent.setClassName(context.getPackageName(), "com.ilmeori.app.MainActivity");
                    appIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    context.startActivity(appIntent);
                }
                break;
            }
        }
    }

    private void refreshAllWidgets(Context context) {
        AppWidgetManager mgr = AppWidgetManager.getInstance(context);
        int[] ids = mgr.getAppWidgetIds(new ComponentName(context, CalendarWidgetProvider.class));
        for (int id : ids) {
            updateWidget(context, mgr, id);
        }
    }

    private void updateWidget(Context context, AppWidgetManager appWidgetManager, int widgetId) {
        SharedPreferences cal = context.getSharedPreferences(CAL_PREFS, Context.MODE_PRIVATE);
        Calendar now = Calendar.getInstance();
        int displayYear = cal.getInt("display_year", now.get(Calendar.YEAR));
        int displayMonth = cal.getInt("display_month", now.get(Calendar.MONTH) + 1);

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_calendar);

        // 헤더: 월 표시
        views.setTextViewText(R.id.calendar_month_text, displayMonth + "월");

        // 오늘 버튼 텍스트
        views.setTextViewText(R.id.btn_today, String.valueOf(now.get(Calendar.DAY_OF_MONTH)));

        // 이전/다음 월 버튼
        views.setOnClickPendingIntent(R.id.btn_prev_month, getBroadcastPI(context, ACTION_PREV_MONTH, 10));
        views.setOnClickPendingIntent(R.id.btn_next_month, getBroadcastPI(context, ACTION_NEXT_MONTH, 11));
        views.setOnClickPendingIntent(R.id.btn_today, getBroadcastPI(context, ACTION_TODAY, 12));

        // + 버튼: 앱의 캘린더 페이지 열기
        Intent addIntent = new Intent(Intent.ACTION_VIEW);
        addIntent.setData(Uri.parse("https://ilmeori.onrender.com/projects/calendar"));
        addIntent.setClassName(context.getPackageName(), "com.ilmeori.app.MainActivity");
        addIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        PendingIntent addPI = PendingIntent.getActivity(context, 13, addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.btn_add_process, addPI);

        // GridView 어댑터 설정
        Intent serviceIntent = new Intent(context, CalendarWidgetService.class);
        serviceIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId);
        serviceIntent.setData(Uri.parse(serviceIntent.toUri(Intent.URI_INTENT_SCHEME)));
        views.setRemoteAdapter(R.id.calendar_grid, serviceIntent);

        // 날짜 클릭 PendingIntent 템플릿
        Intent dateClickIntent = new Intent(context, CalendarWidgetProvider.class);
        dateClickIntent.setAction(ACTION_DATE_CLICK);
        PendingIntent dateClickPI = PendingIntent.getBroadcast(context, 20, dateClickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_MUTABLE);
        views.setPendingIntentTemplate(R.id.calendar_grid, dateClickPI);

        appWidgetManager.updateAppWidget(widgetId, views);

        // 백그라운드에서 API 데이터 가져오기
        ExecutorService executor = Executors.newSingleThreadExecutor();
        Handler handler = new Handler(Looper.getMainLooper());

        executor.execute(() -> {
            try {
                String token = getWidgetToken(context);
                String jsonStr = fetchCalendar(token, displayYear, displayMonth);

                if (jsonStr != null) {
                    JSONObject json = new JSONObject(jsonStr);
                    JSONArray days = json.getJSONArray("days");

                    // SharedPreferences에 캘린더 데이터 저장 (Service가 읽음)
                    cal.edit().putString("calendar_data", days.toString()).apply();

                    handler.post(() -> {
                        // GridView 데이터 새로고침
                        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.calendar_grid);
                    });
                }
            } catch (Exception e) {
                Log.e(TAG, "Fetch error", e);
            }
        });
    }

    private PendingIntent getBroadcastPI(Context context, String action, int requestCode) {
        Intent intent = new Intent(context, CalendarWidgetProvider.class);
        intent.setAction(action);
        return PendingIntent.getBroadcast(context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private String getWidgetToken(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getString(KEY_TOKEN, null);
    }

    private String fetchCalendar(String token, int year, int month) {
        if (token == null || token.isEmpty()) return null;

        try {
            URL url = new URL(API_URL + "?year=" + year + "&month=" + month);
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
                Log.w(TAG, "Calendar API returned " + responseCode);
                return null;
            }
        } catch (Exception e) {
            Log.e(TAG, "Network error", e);
            return null;
        }
    }
}
