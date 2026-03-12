class LegalController < ApplicationController
  skip_before_action :require_login, only: [:terms, :privacy], raise: false

  def terms; end
  def privacy; end
end
