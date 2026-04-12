class SharedDocumentsController < ApplicationController
  # Require no login, as this is a public link
  def show
    @user = User.find_by!(document_share_token: params[:token])
    
    # Hide typical app navigation
    @hide_nav = true
    @is_shared_page = true

    # Parse ?docs= parameter (e.g. docs=card,reg,bank,biz_bank)
    @allowed_docs = params[:docs]&.split(",") || %w[card reg bank biz_bank]
  end
end
