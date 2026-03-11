class NotificationsController < ApplicationController
  def index
    @notifications = Notification.order(created_at: :desc)
    Notification.where(status: "unread").update_all(status: "read")
  end

  def read
    notification = Notification.find(params[:id])
    notification.update(status: "read")
    redirect_to notifications_path
  end
end