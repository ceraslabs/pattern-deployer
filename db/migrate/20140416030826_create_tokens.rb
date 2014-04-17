class CreateTokens < ActiveRecord::Migration
  def up
    create_table :tokens do |t|
      t.string :token
      t.belongs_to :user
      t.belongs_to :topology

      t.timestamps
    end
  end

  def down
    drop_table :tokens
  end
end
