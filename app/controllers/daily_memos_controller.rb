class DailyMemosController < ApplicationController
  before_action :require_login

  def show
    @memo_date = Date.parse(params[:memo_date])
    @memo = current_user.daily_memos.find_or_initialize_by(memo_date: @memo_date)
    @is_today = @memo_date == Time.zone.today
  end

  def update
    memo_date = params[:memo_date]
    memo = current_user.daily_memos.find_or_initialize_by(memo_date: memo_date)
    memo.content = params[:content]
    if memo.save
      respond_to do |format|
        format.html { redirect_to daily_memo_path(memo_date: memo_date), notice: "메모가 저장되었습니다." }
        format.json { render json: { success: true } }
        format.any  { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to daily_memo_path(memo_date: memo_date), alert: "저장에 실패했습니다." }
        format.json { render json: { success: false } }
        format.any  { render json: { success: false } }
      end
    end
  end
end
