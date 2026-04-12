class DailyMemosController < ApplicationController
  before_action :require_login
  before_action :require_standard_for_diary

  def index
    base_year = (params[:year] || Date.current.year).to_i
    base_month = (params[:month] || Date.current.month).to_i

    begin
      @selected_date = Date.new(base_year, base_month, 1)
    rescue ArgumentError
      @selected_date = Date.current.beginning_of_month
    end

    @calendar_year = @selected_date.year
    @calendar_month = @selected_date.month

    @prev_month = @selected_date.last_month
    @next_month = @selected_date.next_month

    current_data = build_month_data_for_diary(@selected_date)
    @calendar_rows = current_data[:rows]
    @memos_by_date = current_data[:memos_by_date]

    @prev_calendar = build_month_data_for_diary(@prev_month)
    @next_calendar = build_month_data_for_diary(@next_month)
  end

  def panel
    base_date = Date.new(params[:year].to_i, params[:month].to_i, 1)
    @calendar_year = base_date.year
    @calendar_month = base_date.month

    data = build_month_data_for_diary(base_date)
    @calendar_rows = data[:rows]
    @memos_by_date = data[:memos_by_date]

    render partial: "daily_memos/calendar_grid", layout: false
  end

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

  private

  def build_month_data_for_diary(base_date)
    start_date = base_date.beginning_of_month.beginning_of_week(:sunday)
    end_date = base_date.end_of_month.end_of_week(:sunday)

    days = (start_date..end_date).to_a
    rows = days.each_slice(7).to_a

    memos_in_range = current_user.daily_memos
      .where(memo_date: start_date..end_date)
      .where.not(content: [ nil, "" ])

    {
      year: base_date.year,
      month: base_date.month,
      rows: rows,
      memos_by_date: memos_in_range.index_by(&:memo_date)
    }
  end

  def require_standard_for_diary
    unless current_user.can_use_daily_diary? || User::TESTING_PERIOD
      redirect_to subscription_path, alert: "일일 다이어리는 스탠다드 이상 요금제에서 이용 가능합니다."
    end
  end
end
