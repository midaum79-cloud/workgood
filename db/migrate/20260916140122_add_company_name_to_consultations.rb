class AddCompanyNameToConsultations < ActiveRecord::Migration[8.1]
  def change
    add_column :consultations, :company_name, :string
  end
end
