class Consultation < ApplicationRecord
  belongs_to :user
  validates :schedule_type, inclusion: { in: %w[consultation as] }
end
