package com.ilmeori.app;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
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
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class CalendarWidgetProvider extends AppWidgetProvider {

    private static final String TAG = "일머리Calendar";
    private static final String API_URL = "https://ilmeori.onrender.com/api/widget/calendar";
    private static final String PREFS_NAME = "ilmeori_widget";
    private static final String KEY_TOKEN = "widget_token";

    // 캘린더 색상
    private static final int BG_COLOR = 0xF01E293B;        // 다크 배경 (반투명)
    private static final int HEADER_COLOR = 0xFFFFFFFF;     // 헤더 텍스트 (흰색)
    private static final int WEEKDAY_COLOR = 0xFF9CA3AF;    // 요일 텍스트
    private static final int DAY_COLOR = 0xFFE5E7EB;        // 이번달 날짜
    private static final int OTHER_MONTH_COLOR = 0xFF4B5563; // 다른달 날짜
    private static final int TODAY_BG = 0xFF2563EB;          // 오늘 배경
    private static final int SUNDAY_COLOR = 0xFFEF4444;      // 일요일
    private static final int SATURDAY_COLOR = 0xFF60A5FA;    // 토요일
    private static final int DIVIDER_COLOR = 0xFF374151;     // 구분선
    private static final int APP_NAME_COLOR = 0xFF6B7280;    // 앱 이름

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

    private void updateWidget(Context context, AppWidgetManager appWidgetManager, int widgetId) {
        // 위젯 크기 가져오기
        Bundle options = appWidgetManager.getAppWidgetOptions(widgetId);
        int widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320);
        int heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 320);

        float density = context.getResources().getDisplayMetrics().density;
        int widthPx = (int)(widthDp * density);
        int heightPx = (int)(heightDp * density);

        // 최소 크기 보장
        widthPx = Math.max(widthPx, (int)(300 * density));
        heightPx = Math.max(heightPx, (int)(300 * density));

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_calendar);

        // 클릭 시 앱의 캘린더 페이지 열기
        Intent launchIntent = new Intent(Intent.ACTION_VIEW, Uri.parse("https://ilmeori.onrender.com/projects/calendar"));
        launchIntent.setPackage(context.getPackageName());
        launchIntent.setClassName(context.getPackageName(), "com.ilmeori.app.MainActivity");
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            context, 1, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        views.setOnClickPendingIntent(R.id.calendar_widget_root, pendingIntent);

        // 로딩 표시 (임시 빈 비트맵)
        Bitmap loadingBmp = createLoadingBitmap(widthPx, heightPx, density);
        views.setImageViewBitmap(R.id.calendar_image, loadingBmp);
        appWidgetManager.updateAppWidget(widgetId, views);

        // 백그라운드에서 데이터 로드 & 캘린더 그리기
        final int w = widthPx, h = heightPx;
        ExecutorService executor = Executors.newSingleThreadExecutor();
        Handler handler = new Handler(Looper.getMainLooper());

        executor.execute(() -> {
            try {
                String token = getWidgetToken(context);
                String jsonStr = fetchCalendar(token);

                handler.post(() -> {
                    try {
                        Bitmap bitmap;
                        if (jsonStr != null) {
                            JSONObject json = new JSONObject(jsonStr);
                            bitmap = drawCalendar(json, w, h, density);
                        } else {
                            bitmap = createLoginRequiredBitmap(w, h, density);
                        }
                        views.setImageViewBitmap(R.id.calendar_image, bitmap);
                        appWidgetManager.updateAppWidget(widgetId, views);
                    } catch (Exception e) {
                        Log.e(TAG, "Render error", e);
                    }
                });
            } catch (Exception e) {
                Log.e(TAG, "Fetch error", e);
            }
        });
    }

    private Bitmap drawCalendar(JSONObject json, int width, int height, float density) throws Exception {
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);

        int year = json.getInt("year");
        int month = json.getInt("month");
        JSONArray days = json.getJSONArray("days");

        float pad = 16 * density;
        float left = pad;
        float top = pad;
        float right = width - pad;
        float bottom = height - pad;
        float contentW = right - left;
        float contentH = bottom - top;

        // 배경 (둥근 모서리)
        Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        bgPaint.setColor(BG_COLOR);
        RectF bgRect = new RectF(0, 0, width, height);
        canvas.drawRoundRect(bgRect, 20 * density, 20 * density, bgPaint);

        // === 헤더: 년월 + 앱이름 ===
        float headerH = 32 * density;
        Paint headerPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        headerPaint.setColor(HEADER_COLOR);
        headerPaint.setTextSize(18 * density);
        headerPaint.setTypeface(Typeface.DEFAULT_BOLD);
        String headerText = year + "년 " + month + "월";
        canvas.drawText(headerText, left + 4 * density, top + 22 * density, headerPaint);

        // 앱이름 (오른쪽)
        Paint appPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        appPaint.setColor(APP_NAME_COLOR);
        appPaint.setTextSize(11 * density);
        appPaint.setTextAlign(Paint.Align.RIGHT);
        canvas.drawText("일머리 ▸", right - 4 * density, top + 20 * density, appPaint);

        float gridTop = top + headerH + 4 * density;

        // === 요일 헤더 ===
        String[] weekdays = {"일", "월", "화", "수", "목", "금", "토"};
        float cellW = contentW / 7f;
        float weekdayH = 18 * density;

        Paint weekdayPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        weekdayPaint.setTextSize(11 * density);
        weekdayPaint.setTypeface(Typeface.DEFAULT_BOLD);
        weekdayPaint.setTextAlign(Paint.Align.CENTER);

        for (int i = 0; i < 7; i++) {
            if (i == 0) weekdayPaint.setColor(SUNDAY_COLOR);
            else if (i == 6) weekdayPaint.setColor(SATURDAY_COLOR);
            else weekdayPaint.setColor(WEEKDAY_COLOR);

            float cx = left + cellW * i + cellW / 2f;
            canvas.drawText(weekdays[i], cx, gridTop + 14 * density, weekdayPaint);
        }

        // 구분선
        Paint linePaint = new Paint();
        linePaint.setColor(DIVIDER_COLOR);
        linePaint.setStrokeWidth(1);
        float lineY = gridTop + weekdayH + 2 * density;
        canvas.drawLine(left, lineY, right, lineY, linePaint);

        // === 날짜 그리드 (6주) ===
        float dateGridTop = lineY + 4 * density;
        float remainH = bottom - dateGridTop - 8 * density;
        float cellH = remainH / 6f;

        Paint datePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        datePaint.setTextSize(13 * density);
        datePaint.setTypeface(Typeface.DEFAULT_BOLD);
        datePaint.setTextAlign(Paint.Align.CENTER);

        Paint todayBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        todayBgPaint.setColor(TODAY_BG);

        Paint dotPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

        int totalDays = Math.min(days.length(), 42);

        for (int i = 0; i < totalDays; i++) {
            JSONObject day = days.getJSONObject(i);
            int row = i / 7;
            int col = i % 7;

            float cx = left + cellW * col + cellW / 2f;
            float cy = dateGridTop + cellH * row;

            int dayNum = day.getInt("day");
            boolean isCurrentMonth = day.getBoolean("current_month");
            boolean isToday = day.getBoolean("today");
            JSONArray items = day.optJSONArray("items");

            // 오늘 배경 원
            if (isToday) {
                canvas.drawCircle(cx, cy + 11 * density, 12 * density, todayBgPaint);
                datePaint.setColor(Color.WHITE);
            } else if (!isCurrentMonth) {
                datePaint.setColor(OTHER_MONTH_COLOR);
            } else if (col == 0) {
                datePaint.setColor(SUNDAY_COLOR);
            } else if (col == 6) {
                datePaint.setColor(SATURDAY_COLOR);
            } else {
                datePaint.setColor(DAY_COLOR);
            }

            // 날짜 숫자
            String dayText = String.valueOf(dayNum);
            canvas.drawText(dayText, cx, cy + 16 * density, datePaint);

            // 공정 색상 도트 (최대 3개)
            if (items != null && items.length() > 0) {
                int dotCount = Math.min(items.length(), 3);
                float dotR = 2.5f * density;
                float dotY = cy + 24 * density;
                float totalDotW = dotCount * dotR * 2 + (dotCount - 1) * 2 * density;
                float dotStartX = cx - totalDotW / 2f + dotR;

                for (int d = 0; d < dotCount; d++) {
                    JSONObject item = items.getJSONObject(d);
                    String colorStr = item.getString("color");
                    try {
                        dotPaint.setColor(Color.parseColor(colorStr));
                    } catch (Exception e) {
                        dotPaint.setColor(0xFF2563EB);
                    }
                    float dotX = dotStartX + d * (dotR * 2 + 2 * density);
                    canvas.drawCircle(dotX, dotY, dotR, dotPaint);
                }
            }
        }

        return bitmap;
    }

    private Bitmap createLoadingBitmap(int width, int height, float density) {
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);

        Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        bgPaint.setColor(BG_COLOR);
        canvas.drawRoundRect(new RectF(0, 0, width, height), 20 * density, 20 * density, bgPaint);

        Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        textPaint.setColor(WEEKDAY_COLOR);
        textPaint.setTextSize(14 * density);
        textPaint.setTextAlign(Paint.Align.CENTER);
        canvas.drawText("📅 캘린더 로딩 중...", width / 2f, height / 2f, textPaint);

        return bitmap;
    }

    private Bitmap createLoginRequiredBitmap(int width, int height, float density) {
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);

        Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        bgPaint.setColor(BG_COLOR);
        canvas.drawRoundRect(new RectF(0, 0, width, height), 20 * density, 20 * density, bgPaint);

        Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        textPaint.setColor(WEEKDAY_COLOR);
        textPaint.setTextSize(14 * density);
        textPaint.setTextAlign(Paint.Align.CENTER);
        canvas.drawText("앱에서 로그인해주세요", width / 2f, height / 2f - 10 * density, textPaint);

        textPaint.setTextSize(12 * density);
        textPaint.setColor(APP_NAME_COLOR);
        canvas.drawText("일머리", width / 2f, height / 2f + 14 * density, textPaint);

        return bitmap;
    }

    private String getWidgetToken(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getString(KEY_TOKEN, null);
    }

    private String fetchCalendar(String token) {
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
                Log.w(TAG, "Calendar API returned " + responseCode);
                return null;
            }
        } catch (Exception e) {
            Log.e(TAG, "Network error", e);
            return null;
        }
    }
}
