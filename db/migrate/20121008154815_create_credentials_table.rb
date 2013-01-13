class CreateCredentialsTable < ActiveRecord::Migration
  def up
    create_table :credentials do |t|
      t.string :type
      t.string :credential_id
      t.string :for_cloud
      t.string :aws_access_key_id
      t.string :aws_secret_access_key
    end
  end

  def down
    drop_table :credentials
  end
end
