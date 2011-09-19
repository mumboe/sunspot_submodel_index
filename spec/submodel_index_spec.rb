require File.expand_path('../spec_helper', __FILE__)

def stub_object_no_index(new_record = false)
  obj = SunspotSubmodelTestModel.new
  obj.class._sunspot_submodel_options[:if] = nil
  obj.class._sunspot_submodel_options[:included_attributes] = false
  obj.class._sunspot_submodel_options[:ignored_attributes] = false
  obj.stubs(:new_record?).returns(new_record)
  parent_mock = mock()
  parent_mock.expects(:solr_index).never
  obj.stubs(:parent_model).returns(parent_mock)
  obj
end

def stub_object_array_parents(number_of_parents = 2, new_record = false, should_index = true)
  obj = SunspotSubmodelTestModel.new
  obj.class._sunspot_submodel_options[:included_attributes] = false
  obj.class._sunspot_submodel_options[:ignored_attributes] = false
  obj.stubs(:new_record?).returns(new_record)
  parents = []
  number_of_parents.times do |i|
    parent_mock = mock()
    should_index ? parent_mock.expects(:solr_index) : parent_mock.expects(:solr_index).never
    parents << parent_mock
  end
  obj.stubs(:parent_model).returns(parents)
  obj
end

def stub_object_will_index(new_record = false)
  obj = SunspotSubmodelTestModel.new
  obj.class._sunspot_submodel_options[:if] = nil
  obj.class._sunspot_submodel_options[:included_attributes] = false
  obj.class._sunspot_submodel_options[:ignored_attributes] = false
  obj.stubs(:new_record?).returns(new_record)
  parent_mock = mock()
  parent_mock.expects(:solr_index)
  obj.stubs(:parent_model).returns(parent_mock)
  obj
end

describe Sunspot::SubmodelIndex do 
  
  before :all do
    ActiveRecord::Base.establish_connection("adapter" => "sqlite3", "database" => ":memory:")
    SunspotSubmodelTestModel.create_table
  end
  
  after :all do
    ActiveRecord::Base.connection.disconnect!
  end
  
  context "new record" do
     it "should call solr_index on parent_model on save" do
       obj = stub_object_will_index(true)
       obj.save
     end
   end
   
   
   context "for existing records" do
     it "should reindex if no attributes options are set on save if no attributes are included or excluded" do
       obj = stub_object_will_index
       obj.save
     end
     context "when something changes and an if option is set" do
       it "should not reindex if the if proc returns false" do
         obj = stub_object_no_index
         obj.expects(:check_parent_solr_if_statement).returns false
         obj.save
       end
       it "should reindex if the if proc returns true" do
         obj = stub_object_will_index
         obj.expects(:check_parent_solr_if_statement).returns true
         obj.save
       end
     end
     context "included_attributes" do
       it "should not index if no included attribute is changed" do
         obj = stub_object_no_index
         obj.class._sunspot_submodel_options[:included_attributes] = [:test, :test2]
         obj.stubs(:changed).returns ["test3"]
         obj.save
       end
       it "should index if any included attribute is changed" do
         obj = stub_object_will_index
         obj.class._sunspot_submodel_options[:included_attributes] = [:test, :test2]
         obj.stubs(:changed).returns ["test2"]
         obj.save
       end
       it "should not index if no changes are made" do
         obj = stub_object_no_index
         obj.class._sunspot_submodel_options[:included_attributes] = [:test, :test2]
         obj.stubs(:changed).returns []
         obj.save
       end
     end
     context "ignored attributes" do
       it "should not index if only ignored attributes are changed" do
         obj = stub_object_no_index
         obj.class._sunspot_submodel_options[:ignored_attributes] = [:test, :test2]
         obj.stubs(:changed).returns ["test2","test"]
         obj.save
       end
       it "should not index if no attributes are changed" do
         obj = stub_object_no_index
         obj.class._sunspot_submodel_options[:ignored_attributes] = [:test, :test2]
         obj.stubs(:changed).returns []
         obj.save
       end
       it "should index if a non ignored attribute is changed" do
         obj = stub_object_will_index
         obj.class._sunspot_submodel_options[:ignored_attributes] = [:test, :test2]
         obj.stubs(:changed).returns ["test3"]
         obj.save
       end
       it "should use included attributes if both are set" do
         obj = stub_object_will_index
         obj.class._sunspot_submodel_options[:included_attributes] = [:test]
         obj.class._sunspot_submodel_options[:ignored_attributes] = [:test, :test2]
         obj.stubs(:changed).returns ["test"]
         obj.save
       end
     end
   end
   
   context "parents that are multiple objects" do
     #Example is a has_many or has_and_belongs_to_many
     it "should index several parents if they are an array" do
       obj = stub_object_array_parents(2,false,true)
       obj.class._sunspot_submodel_options[:included_attributes] = [:test]
       obj.stubs(:changed).returns ["test"]
       obj.save
     end
     it "should not fail if the array is empty" do
       obj = stub_object_array_parents(0,false,true)
       obj.class._sunspot_submodel_options[:included_attributes] = [:test]
       obj.stubs(:changed).returns ["test"]
       obj.save
     end
     it "should respect the if statement even if the parents are an array" do
       obj = stub_object_array_parents(2,false,false)
       obj.class._sunspot_submodel_options[:included_attributes] = [:test]
       obj.stubs(:changed).returns ["test"]
       obj.class._sunspot_submodel_options[:if] = Proc.new {|t| false }
       obj.save
     end
   end
    
   
   context "on destroy" do
     it "should call parents index" do
       obj = stub_object_will_index
       obj.destroy
     end
     it "should not call parents index if the if proc fails" do
       obj = stub_object_no_index
       obj.expects(:check_parent_solr_if_statement).returns false
       obj.destroy
     end
     it "should call parents index if the if proc is ok" do
       obj = stub_object_will_index
       obj.expects(:check_parent_solr_if_statement).returns true
       obj.destroy
     end
   end
   
   context "force association reload" do
     it "should call parent with true with option is set" do
       obj = SunspotSubmodelTestModel.new
       obj.class._sunspot_submodel_options[:force_association_reload] = true
       parent_mock = mock()
       parent_mock.expects(:solr_index)
       obj.expects(:parent_model).with().returns(parent_mock)
       obj.expects(:parent_model).with(true).returns(parent_mock)
       obj.expects(:parent_model).with().returns(parent_mock)
       obj.expects(:parent_model).with().returns(parent_mock)
       obj.call_parent_solr_index
     end
     it "should not call parent with true if option is not set" do
       obj = SunspotSubmodelTestModel.new
       obj.class._sunspot_submodel_options[:force_association_reload] = false
       parent_mock = mock()
       parent_mock.expects(:solr_index)
       obj.expects(:parent_model).with().returns(parent_mock).times(3)
       obj.call_parent_solr_index
     end
   end
   
   
   context "check_parent_solr_if_statement" do
     before do
       @obj = SunspotSubmodelTestModel.new
       @obj.class._sunspot_submodel_options[:if] = nil
     end
     after do
       @obj.class._sunspot_submodel_options[:if] = nil
     end
     it "should return true if no option is set" do
       @obj.send(:check_parent_solr_if_statement).should == true
     end
     it "should return true if the if option is not a proc" do
       @obj.class._sunspot_submodel_options[:if] = "not a proc"
       @obj.send(:check_parent_solr_if_statement).should == true
     end
     it "should return true if the if proc returns true" do
       @obj.class._sunspot_submodel_options[:if] = Proc.new {|t| true }
       @obj.send(:check_parent_solr_if_statement).should == true
     end
     it "should return false if the if proc returns false" do
       @obj.class._sunspot_submodel_options[:if] = Proc.new {|t| false }
       @obj.send(:check_parent_solr_if_statement).should == false
     end
     it "should pass in the instance of the model" do
       @obj.class._sunspot_submodel_options[:if] = Proc.new {|t| t.proc_test }
       @obj.stubs(:proc_test).returns(false)
       @obj.send(:check_parent_solr_if_statement).should == false
     end
   end 

end
