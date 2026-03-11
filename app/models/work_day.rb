class WorkDay < ApplicationRecord
  belongs_to :work_process

  validates :work_date, presence: true
end