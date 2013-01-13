class AddAttrsToService < ActiveRecord::Migration
  def change
    add_column :services, :attrs, :text
  end
end
