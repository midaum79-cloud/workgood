class DailyMemosController < ApplicationController
  before_action :require_login

  def update
    memo_date = params[:memo_date]
    memo = current_user.daily_memos.find_or_initialize_by(memo_date: memo_date)
    memo.content = params[:content]
    if memo.save
      render json: { success: true }
    else
      render json: { success: false, error: memo.errors.full_messages.join(", ") }
    end
  end
end
