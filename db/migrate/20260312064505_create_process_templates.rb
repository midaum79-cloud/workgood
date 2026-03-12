class CreateProcessTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :process_templates do |t|
      t.string :name
      t.integer :position
      t.boolean :is_default

      t.timestamps
    end
  end
end
