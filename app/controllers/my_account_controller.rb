class MyAccountController < ApplicationController
  before_action :require_login

  def show
    @project_count   = current_user.projects.count
    @plan_limit      = current_user.plan_limit
  end
end
