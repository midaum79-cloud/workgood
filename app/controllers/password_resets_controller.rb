class PasswordResetsController < ApplicationController
  layout false
  before_action :load_user_from_token, only: %i[edit update]

  # GET /password_resets/new
  def new
  end

  # POST /password_resets
  def create
    @user = User.find_by(email: params[:email].to_s.strip.downcase)
    if @user
      token = SecureRandom.urlsafe_base64(32)
      @user.update!(
        password_reset_token: token,
        password_reset_sent_at: Time.current
      )
      UserMailer.password_reset(@user).deliver_now
    end
    # Always show the same message to prevent email enumeration
    redirect_to login_path, notice: "비밀번호 재설정 이메일을 발송했습니다. 받은 편지함을 확인해 주세요."
  end

  # GET /password_resets/:token/edit
  def edit
  end

  # PATCH /password_resets/:token
  def update
    if @user.password_reset_sent_at < 2.hours.ago
      redirect_to new_password_reset_path, alert: "비밀번호 재설정 링크가 만료되었습니다. 다시 요청해 주세요."
      return
    end

    if params[:password].blank?
      flash.now[:alert] = "비밀번호를 입력해 주세요."
      render :edit, status: :unprocessable_entity
      return
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "비밀번호가 일치하지 않습니다."
      render :edit, status: :unprocessable_entity
      return
    end

    if params[:password].length < 8
      flash.now[:alert] = "비밀번호는 8자 이상이어야 합니다."
      render :edit, status: :unprocessable_entity
      return
    end

    @user.update!(
      password: params[:password],
      password_confirmation: params[:password_confirmation],
      password_reset_token: nil,
      password_reset_sent_at: nil
    )
    session[:user_id] = @user.id
    redirect_to root_path, notice: "비밀번호가 변경되었습니다. 자동으로 로그인되었습니다."
  end

  private

  def load_user_from_token
    @user = User.find_by(password_reset_token: params[:token])
    unless @user
      redirect_to new_password_reset_path, alert: "잘못된 링크입니다. 다시 시도해 주세요."
    end
  end
end
