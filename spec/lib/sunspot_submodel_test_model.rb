class SunspotSubmodelTestModel < ActiveRecord::Base
  
  sunspot_submodel_index :parent => :parent_model
  
  def self.create_table
    connection.create_table :sunspot_submodel_test_models do |t|
      t.integer :parent_id
    end
  end

  def title
    "Fake AR"
  end
  
  def parent_model
    return nil
  end
  
  private
  
end
