class Consultation < ApplicationRecord
  belongs_to :user
  validates :schedule_type, inclusion: { in: %w[consultation as] }
  validates :company_name, presence: { message: "업체명을 입력해주세요." }
  validates :contact_number, presence: { message: "연락처를 입력해주세요." }
end
