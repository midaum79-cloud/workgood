package com.ilmeori.app;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.view.View;
import android.widget.RemoteViews;
import android.widget.RemoteViewsService;

import org.json.JSONArray;
import org.json.JSONObject;

public class CalendarWidgetService extends RemoteViewsService {

    @Override
    public RemoteViewsFactory onGetViewFactory(Intent intent) {
        return new CalendarRemoteViewsFactory(getApplicationContext());
    }

    static class CalendarRemoteViewsFactory implements RemoteViewsFactory {
        private Context context;
        private JSONArray days;

        CalendarRemoteViewsFactory(Context context) {
            this.context = context;
        }

        @Override
        public void onCreate() {
            loadData();
        }

        @Override
        public void onDataSetChanged() {
            loadData();
        }

        private void loadData() {
            SharedPreferences prefs = context.getSharedPreferences("ilmeori_calendar_widget", Context.MODE_PRIVATE);
            String json = prefs.getString("calendar_data", "[]");
            try {
                days = new JSONArray(json);
            } catch (Exception e) {
                days = new JSONArray();
            }
        }

        @Override
        public int getCount() {
            return days != null ? days.length() : 42;
        }

        @Override
        public RemoteViews getViewAt(int position) {
            RemoteViews rv = new RemoteViews(context.getPackageName(), R.layout.widget_calendar_cell);

            try {
                if (days == null || position >= days.length()) {
                    rv.setTextViewText(R.id.date_text, "");
                    return rv;
                }

                JSONObject day = days.getJSONObject(position);
                int dayNum = day.getInt("day");
                boolean isCurrentMonth = day.getBoolean("current_month");
                boolean isToday = day.getBoolean("today");
                String dateStr = day.getString("date");
                JSONArray items = day.optJSONArray("items");
                int col = position % 7;

                // 날짜 텍스트
                rv.setTextViewText(R.id.date_text, String.valueOf(dayNum));

                // 색상 설정
                if (isToday) {
                    rv.setViewVisibility(R.id.today_circle, View.VISIBLE);
                    rv.setInt(R.id.today_circle, "setBackgroundResource", R.drawable.widget_today_circle);
                    rv.setTextColor(R.id.date_text, Color.WHITE);
                } else {
                    rv.setViewVisibility(R.id.today_circle, View.GONE);
                    if (!isCurrentMonth) {
                        rv.setTextColor(R.id.date_text, Color.parseColor("#D1D5DB"));
                    } else if (col == 0) {
                        rv.setTextColor(R.id.date_text, Color.parseColor("#EF4444")); // 일요일
                    } else if (col == 6) {
                        rv.setTextColor(R.id.date_text, Color.parseColor("#3B82F6")); // 토요일
                    } else {
                        rv.setTextColor(R.id.date_text, Color.parseColor("#111827"));
                    }
                }

                // 공정 색상 도트 (최대 3개)
                int[] dotIds = {R.id.dot1, R.id.dot2, R.id.dot3};
                for (int i = 0; i < 3; i++) {
                    if (items != null && i < items.length()) {
                        rv.setViewVisibility(dotIds[i], View.VISIBLE);
                        rv.setInt(dotIds[i], "setBackgroundResource", R.drawable.widget_dot);
                        try {
                            String colorStr = items.getJSONObject(i).getString("color");
                            // RemoteViews doesn't support setBackgroundColor on View directly
                            // We use a colored drawable via setInt
                            rv.setInt(dotIds[i], "setBackgroundColor", Color.parseColor(colorStr));
                        } catch (Exception e) {
                            rv.setInt(dotIds[i], "setBackgroundColor", Color.parseColor("#2563EB"));
                        }
                    } else {
                        rv.setViewVisibility(dotIds[i], View.GONE);
                    }
                }

                // 날짜 클릭 시 앱 캘린더로 이동하기 위한 fill-in intent
                Intent fillIntent = new Intent();
                fillIntent.putExtra("selected_date", dateStr);
                rv.setOnClickFillInIntent(R.id.cell_root, fillIntent);

            } catch (Exception e) {
                rv.setTextViewText(R.id.date_text, "");
            }

            return rv;
        }

        @Override
        public RemoteViews getLoadingView() {
            return null;
        }

        @Override
        public int getViewTypeCount() {
            return 1;
        }

        @Override
        public long getItemId(int position) {
            return position;
        }

        @Override
        public boolean hasStableIds() {
            return true;
        }

        @Override
        public void onDestroy() {
            days = null;
        }
    }
}
