class SharedProjectsController < ApplicationController
  skip_before_action :require_login, only: [:show]
  layout false

  def show
    @project = Project.find_signed!(params[:token], purpose: :share_schedule)
    @team_leader = @project.user
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    render plain: "유효하지 않거나 삭제된 현장 공유 링크입니다.", status: :not_found
  end
end
