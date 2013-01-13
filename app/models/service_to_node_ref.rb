class ServiceToNodeRef < ActiveRecord::Base

  belongs_to :service, :autosave => true
  belongs_to :node, :autosave => true

  attr_accessible :ref_name, :service, :node
end
