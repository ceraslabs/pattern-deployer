# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130321231544) do

  create_table "containers", :force => true do |t|
    t.string   "container_id"
    t.integer  "num_of_copies"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
    t.integer  "topology_id"
    t.integer  "user_id",       :null => false
  end

  add_index "containers", ["container_id"], :name => "index_containers_on_container_id"

  create_table "credentials", :force => true do |t|
    t.string  "type"
    t.string  "credential_id"
    t.string  "for_cloud"
    t.string  "aws_access_key_id"
    t.string  "aws_secret_access_key"
    t.string  "openstack_username"
    t.string  "openstack_password"
    t.string  "openstack_tenant"
    t.string  "openstack_endpoint"
    t.integer "user_id",               :null => false
  end

  create_table "nodes", :force => true do |t|
    t.string   "node_id"
    t.text     "attrs"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
    t.integer  "parent_id"
    t.string   "parent_type"
    t.integer  "container_node_id"
    t.integer  "user_id",           :null => false
    t.integer  "topology_id"
    t.text     "nested_nodes_info"
  end

  add_index "nodes", ["node_id"], :name => "index_nodes_on_node_id"

  create_table "nodes_templates", :id => false, :force => true do |t|
    t.integer "node_id"
    t.integer "template_id"
  end

  add_index "nodes_templates", ["node_id", "template_id"], :name => "index_nodes_templates_on_node_id_and_template_id"
  add_index "nodes_templates", ["template_id", "node_id"], :name => "index_nodes_templates_on_template_id_and_node_id"

  create_table "rails_admin_histories", :force => true do |t|
    t.text     "message"
    t.string   "username"
    t.integer  "item"
    t.string   "table"
    t.integer  "month",      :limit => 2
    t.integer  "year",       :limit => 8
    t.datetime "created_at",              :null => false
    t.datetime "updated_at",              :null => false
  end

  add_index "rails_admin_histories", ["item", "table", "month", "year"], :name => "index_rails_admin_histories"

  create_table "service_to_node_refs", :force => true do |t|
    t.string   "ref_name"
    t.integer  "service_id"
    t.integer  "node_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "services", :force => true do |t|
    t.string   "service_id"
    t.text     "properties"
    t.datetime "created_at",             :null => false
    t.datetime "updated_at",             :null => false
    t.integer  "service_container_id"
    t.string   "service_container_type"
    t.integer  "user_id",                :null => false
    t.integer  "topology_id"
  end

  add_index "services", ["service_id"], :name => "index_services_on_service_id"

  create_table "supporting_services", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.string   "state"
    t.integer  "user_id",    :null => false
  end

  create_table "template_inheritances", :force => true do |t|
    t.integer  "template_id"
    t.integer  "base_template_id"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  create_table "templates", :force => true do |t|
    t.string   "template_id"
    t.text     "attrs"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "topology_id"
    t.integer  "user_id",     :null => false
  end

  add_index "templates", ["template_id"], :name => "index_templates_on_template_id"

  create_table "topologies", :force => true do |t|
    t.string   "topology_id"
    t.text     "description"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "state"
    t.integer  "user_id",     :null => false
  end

  add_index "topologies", ["topology_id"], :name => "index_topologies_on_topology_id"

  create_table "uploaded_files", :force => true do |t|
    t.string   "type"
    t.string   "key_pair_id"
    t.string   "for_cloud"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "file_name"
    t.integer  "user_id",     :null => false
  end

  create_table "users", :force => true do |t|
    t.string   "email",                  :default => "",     :null => false
    t.string   "encrypted_password",     :default => "",     :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                                 :null => false
    t.datetime "updated_at",                                 :null => false
    t.string   "role",                   :default => "user", :null => false
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

end
