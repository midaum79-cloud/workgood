class AddUserIdToNotifications < ActiveRecord::Migration[8.1]
  def up
    # user_id 컬럼 추가 (nullable로 시작 → 기존 데이터 대응)
    add_reference :notifications, :user, null: true, foreign_key: true

    # 기존 알림들: project → user 역추적으로 user_id 채우기
    execute <<~SQL
      UPDATE notifications
      SET user_id = projects.user_id
      FROM projects
      WHERE notifications.project_id = projects.id
        AND notifications.user_id IS NULL
    SQL

    # 이후 신규 알림은 반드시 user_id 필요
    # (기존 데이터 중 project 없는 레코드는 null 허용)
  end

  def down
    remove_reference :notifications, :user, foreign_key: true
  end
end
