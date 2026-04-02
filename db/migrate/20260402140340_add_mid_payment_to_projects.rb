class AddMidPaymentToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :mid_payment, :integer
  end
end
