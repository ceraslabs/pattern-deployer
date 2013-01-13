class RemoveDefaultValueOfOwner < ActiveRecord::Migration
  def up
    change_column_default :containers, :user_id, nil
    change_column_default :credentials, :user_id, nil
    change_column_default :nodes, :user_id, nil
    change_column_default :services, :user_id, nil
    change_column_default :supporting_services, :user_id, nil
    change_column_default :templates, :user_id, nil
    change_column_default :topologies, :user_id, nil
    change_column_default :uploaded_files, :user_id, nil
  end

  def down
    change_column_default :containers, :user_id, 3
    change_column_default :credentials, :user_id, 3
    change_column_default :nodes, :user_id, 3
    change_column_default :services, :user_id, 3
    change_column_default :supporting_services, :user_id, 3
    change_column_default :templates, :user_id, 3
    change_column_default :topologies, :user_id, 3
    change_column_default :uploaded_files, :user_id, 3
  end
end
