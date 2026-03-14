class UserMailer < ApplicationMailer
  def password_reset(user)
    @user = user
    @reset_url = edit_password_reset_url(token: user.password_reset_token)
    mail(to: user.email, subject: "[일머리] 비밀번호 재설정 안내")
  end
end
