class LegalController < ApplicationController
  skip_before_action :require_login, only: [:terms, :privacy, :guide], raise: false

  def terms; end
  def privacy; end
  def guide; end
end
