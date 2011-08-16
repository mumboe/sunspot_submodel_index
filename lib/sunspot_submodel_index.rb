require 'sunspot_submodel_index/submodel_index'

if ActiveRecord::VERSION::MAJOR > 2
  ActiveSupport.on_load(:active_record) do
    include(Sunspot::SubmodelIndex)
  end
else
  ActiveRecord::Base.send(:include, Sunspot::SubmodelIndex)
end
