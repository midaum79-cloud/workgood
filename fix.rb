content = File.read("app/views/subscriptions/index.html.erb")

old_str = <<-HTML
      <%# ===== PREMIUM ===== %>
      <% is_current = @current_plan == "premium" %>
      <div style="background:linear-gradient(135deg, #1e1b4b 0%, #312e81 100%); border-radius:20px; padding:20px; border:2px solid <%= is_current ? '#818cf8' : '#6366f1' %>; position:relative; overflow:hidden; box-shadow:0 8px 32px rgba(99,102,241,0.3);">
        <div style="position:absolute; top:-30px; right:-30px; width:120px; height:120px; border-radius:50%; background:rgba(255,255,255,0.05);"></div>
        <div style="position:absolute; bottom:-20px; left:-20px; width:80px; height:80px; border-radius:50%; background:rgba(255,255,255,0.03);"></div>

        <%# 프리미엄 추천 뱃지 %>
        <div style="position:absolute; top:-10px; left:16px; background:linear-gradient(135deg, #f59e0b, #ef4444); color:white; font-size:11px; font-weight:900; padding:5px 14px; border-radius:999px; box-shadow:0 2px 8px rgba(239,68,68,0.4);">
          🔥 추천
        </div>
HTML

new_str = <<-HTML
      <%# ===== PREMIUM ===== %>
      <% is_current = @current_plan == "premium" %>
      <div style="position:relative;">
        <%# 프리미엄 추천 뱃지 %>
        <div style="position:absolute; top:-10px; left:16px; background:linear-gradient(135deg, #f59e0b, #ef4444); color:white; font-size:11px; font-weight:900; padding:5px 14px; border-radius:999px; box-shadow:0 2px 8px rgba(239,68,68,0.4); z-index:10;">
          🔥 추천
        </div>

        <div style="background:linear-gradient(135deg, #1e1b4b 0%, #312e81 100%); border-radius:20px; padding:20px; border:2px solid <%= is_current ? '#818cf8' : '#6366f1' %>; position:relative; overflow:hidden; box-shadow:0 8px 32px rgba(99,102,241,0.3);">
          <div style="position:absolute; top:-30px; right:-30px; width:120px; height:120px; border-radius:50%; background:rgba(255,255,255,0.05);"></div>
          <div style="position:absolute; bottom:-20px; left:-20px; width:80px; height:80px; border-radius:50%; background:rgba(255,255,255,0.03);"></div>
HTML

content = content.sub(old_str.strip, new_str.strip)

old_end = <<-HTML
        <% if is_current %>
          <div style="text-align:center; padding:13px; background:rgba(255,255,255,0.1); border-radius:14px; font-size:15px; font-weight:800; color:white;">현재 플랜</div>
        <% else %>
          <button onclick="requestPayment('premium', 9900)" style="width:100%; padding:14px; background:linear-gradient(135deg, #f59e0b, #ef4444); color:white; border:none; border-radius:14px; font-size:16px; font-weight:900; cursor:pointer; font-family:inherit; box-shadow:0 4px 12px rgba(239,68,68,0.3);">
            프리미엄 혜택받기 · ₩9,900/월
          </button>
        <% end %>
      </div>
    </div>
HTML

new_end = <<-HTML
        <% if is_current %>
          <div style="text-align:center; padding:13px; background:rgba(255,255,255,0.1); border-radius:14px; font-size:15px; font-weight:800; color:white;">현재 플랜</div>
        <% else %>
          <button onclick="requestPayment('premium', 9900)" style="width:100%; padding:14px; background:linear-gradient(135deg, #f59e0b, #ef4444); color:white; border:none; border-radius:14px; font-size:16px; font-weight:900; cursor:pointer; font-family:inherit; box-shadow:0 4px 12px rgba(239,68,68,0.3);">
            프리미엄 혜택받기 · ₩9,900/월
          </button>
        <% end %>
        </div>
      </div>
    </div>
HTML

content = content.sub(old_end.strip, new_end.strip)

File.write("app/views/subscriptions/index.html.erb", content)
