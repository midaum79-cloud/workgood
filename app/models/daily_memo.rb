class DailyMemo < ApplicationRecord
  belongs_to :user

  PER_PAGE = 20

  scope :page_memo, ->(page) {
    page = (page || 1).to_i
    offset((page - 1) * PER_PAGE).limit(PER_PAGE)
  }
end
