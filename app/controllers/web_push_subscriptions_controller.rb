class WebPushSubscriptionsController < ApplicationController
  before_action :authenticate_user! # Ensure only logged-in users can subscribe

  def create
    subscription = current_user.web_push_subscriptions.find_or_initialize_by(
      endpoint: subscription_params[:endpoint]
    )

    subscription.assign_attributes(
      p256dh: subscription_params[:keys][:p256dh],
      auth: subscription_params[:keys][:auth]
    )

    if subscription.save
      render json: { success: true }, status: :ok
    else
      render json: { error: subscription.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    subscription = current_user.web_push_subscriptions.find_by(endpoint: params[:endpoint])
    
    if subscription&.destroy
      render json: { success: true }, status: :ok
    else
      render json: { error: "Subscription not found" }, status: :not_found
    end
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
  end
end
