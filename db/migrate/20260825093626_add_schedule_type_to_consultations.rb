class AddScheduleTypeToConsultations < ActiveRecord::Migration[8.1]
  def change
    add_column :consultations, :schedule_type, :string, default: 'consultation'
  end
end
