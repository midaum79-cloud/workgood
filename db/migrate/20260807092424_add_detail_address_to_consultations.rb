class AddDetailAddressToConsultations < ActiveRecord::Migration[8.1]
  def change
    add_column :consultations, :detail_address, :string
  end
end
