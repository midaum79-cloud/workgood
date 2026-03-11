class Notification < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :work_process, optional: true

  scope :unread, -> { where(status: "unread") }

  def mark_as_read
    update(status: "read")
  end
end