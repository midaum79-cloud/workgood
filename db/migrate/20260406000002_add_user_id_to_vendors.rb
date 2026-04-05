class AddUserIdToVendors < ActiveRecord::Migration[8.1]
  def up
    add_column :vendors, :user_id, :bigint
    add_index :vendors, :user_id

    # 기존 거래처: 프로젝트 연결로 user_id 역추적 불가 (vendor는 user 직접 귀속)
    # 현재 운영자 계정(가장 오래된 user)으로 임시 귀속 → 실운영에서 수동 정리 필요
    execute <<~SQL
      UPDATE vendors
      SET user_id = (SELECT id FROM users ORDER BY id ASC LIMIT 1)
      WHERE user_id IS NULL
    SQL

    # FK 추가
    add_foreign_key :vendors, :users
  end

  def down
    remove_foreign_key :vendors, :users
    remove_index :vendors, :user_id
    remove_column :vendors, :user_id
  end
end
