require "csv"

class TaxReportsController < ApplicationController
  before_action :require_login
  before_action :require_premium

  def index
    @year = (params[:year] || Date.current.year).to_i
    @years = (2023..Date.current.year).to_a.reverse

    # 해당 연도 전체 현장
    @projects = current_user.projects
      .where("EXTRACT(year FROM start_date) = ? OR EXTRACT(year FROM end_date) = ?", @year, @year)
      .order(start_date: :asc)

    # 수입 집계
    @total_estimate  = @projects.sum { |p| p.estimate_amount.to_i }
    @total_collected = @projects.sum(&:total_collected)
    @total_outstanding = @projects.sum(&:outstanding_balance)

    # 세금계산서 vs 일용근로 분리
    @invoice_projects = @projects.select { |p| p.tax_invoice_issued? }
    @regular_projects = @projects.reject { |p| p.tax_invoice_issued? }

    @invoice_collected = @invoice_projects.sum(&:total_collected)
    @regular_collected = @regular_projects.sum(&:total_collected)

    # 세금 계산: 일용근로 3.3% / 세금계산서 10% 부가세
    @tax_rate        = 3.3
    @withholding_tax = (@regular_collected * @tax_rate / 100).round
    @invoice_vat     = (@invoice_collected * 10.0 / 110).round  # 부가세 = 공급가액의 10%, 총액의 10/110
    @net_income      = @total_collected - @withholding_tax - @invoice_vat

    # 월별 수입 집계
    @monthly_stats = (1..12).map do |month|
      month_projects = @projects.select do |p|
        p.start_date&.year == @year && p.start_date&.month == month ||
        p.end_date&.year == @year && p.end_date&.month == month
      end
      collected = month_projects.sum(&:total_collected)
      {
        month: month,
        count: month_projects.size,
        collected: collected,
        tax: (collected * @tax_rate / 100).round,
        net: collected - (collected * @tax_rate / 100).round
      }
    end

    # 미수금 현장 목록
    @outstanding_projects = @projects.select { |p| p.outstanding_balance > 0 }
  end

  def download
    year = (params[:year] || Date.current.year).to_i
    projects = current_user.projects
      .where("EXTRACT(year FROM start_date) = ? OR EXTRACT(year FROM end_date) = ?", year, year)
      .order(start_date: :asc)

    tax_rate = 3.3

    csv_data = CSV.generate(encoding: "UTF-8") do |csv|
      # 헤더
      csv << [ "#{year}년 종합소득세 정산 리포트", "", "", "", "", "", "", "" ]
      csv << [ "생성일: #{Date.current}", "", "", "", "", "", "", "" ]
      csv << []
      csv << [ "현장명", "거래처", "시작일", "종료일", "견적금액", "계약금", "중도금", "수금합계", "미수금", "결제상태", "원천징수(3.3%)", "실수령액" ]

      projects.each do |p|
        est       = p.estimate_amount.to_i
        dep       = p.deposit_amount.to_i
        mid       = p.mid_payment.to_i
        collected = p.total_collected
        outstanding = p.outstanding_balance
        tax       = (collected * tax_rate / 100).round
        net       = collected - tax

        csv << [
          p.project_name,
          p.client_name,
          p.start_date&.strftime("%Y-%m-%d"),
          p.end_date&.strftime("%Y-%m-%d"),
          est,
          dep,
          mid,
          collected,
          outstanding,
          p.payment_status.presence || "미결제",
          tax,
          net
        ]
      end

      csv << []
      total_collected = projects.sum(&:total_collected)
      total_tax = (total_collected * tax_rate / 100).round
      csv << [ "합계", "", "", "", projects.sum(:estimate_amount).to_i, "", "", total_collected, "", "", total_tax, total_collected - total_tax ]
    end

    # BOM 추가 (엑셀 한글 인코딩)
    send_data "\xEF\xBB\xBF" + csv_data,
      filename: "#{year}년_세금정산_리포트_#{Date.current}.csv",
      type: "text/csv; charset=UTF-8",
      disposition: "attachment"
  end

  def send_payment_request
    project_id = params[:project_id]
    project = current_user.projects.find_by(id: project_id)

    if project
      outstanding = project.outstanding_balance
      Notification.create!(
        user: current_user,
        project: project,
        title: "미수금 입금 요청",
        message: "#{project.project_name} (#{project.client_name}) - 잔금 #{outstanding.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}원을 확인해주세요.",
        status: "unread",
        category: "finance",
        link_url: "/projects/#{project.id}"
      )
      redirect_to tax_report_path(year: params[:year]), notice: "알림이 등록되었습니다."
    else
      redirect_to tax_report_path, alert: "현장을 찾을 수 없습니다."
    end
  end

  def daily_worker_tax
    # 일용직 인건비 역산 계산기 페이지 (JS로 동작하므로 넘겨줄 변수는 없음)
  end

  private

  def require_premium
    unless current_user.premium? || User::TESTING_PERIOD
      redirect_to subscription_path, alert: "프리미엄 플랜에서 이용 가능한 기능입니다."
    end
  end
end
