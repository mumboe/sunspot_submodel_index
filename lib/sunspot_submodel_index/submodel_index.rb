module Sunspot
  module SubmodelIndex
    
    def self.included(klass)
      klass.class_eval do
        
        # Solr Index a parent model when this model is saved or destroyed.
        #
        # ==== Options (+options+)
        # 
        # :parent<Symbol>::
        #   Method to call to access the parent to Solr index.
        # :if<Proc>::
        #   A Proc that is called before the parent index and is passed an instance of the object.
        #   Will block Solr index of the parent if false is returned.
        # :force_association_reload<Boolean>::
        #   Force a reload on the parent association for Solr index is called on the parent.
        # :include_attributes<Array>::
        #   Define only those attributes whose change should trigger a reindex of the parent.
        # :ignore_attributes<Array>::
        #   Define attributes, that should not trigger a reindex of the parent.
        #
        # ==== Example
        #
        #   class Company < ActiveRecord::Base
        #     has_many :people
        #     sunspot_submodel_index :parent => :people, :included_attributes => [:name]
        #   end
        #
        def self.sunspot_submodel_index(options = {})
          include Sunspot::SubmodelIndex::InstanceMethods
          extend Sunspot::SubmodelIndex::ClassMethods
          class_inheritable_hash :_sunspot_submodel_options
          
          options[:parent] = options[:parent].to_sym
          options[:included_attributes] =  false if options[:included_attributes].blank? #set to false if empty sent
          options[:ignored_attributes] =  false if options[:ignored_attributes].blank? #set to false if empty sent
          options[:force_association_reload] =  false if options[:force_association_reload].blank? #set to false if empty sent
          
          self._sunspot_submodel_options = options
          
          #add call backs
          before_save :mark_for_parent_solr_index
          after_save :parent_solr_index
          after_destroy :parent_solr_index_on_destroy
          
        end
        
      end
    end

    module InstanceMethods
      
      def call_parent_solr_index
        if self.respond_to?(self._sunspot_submodel_options[:parent]) && !self.send(self._sunspot_submodel_options[:parent]).nil?
          self.send(self._sunspot_submodel_options[:parent],true) if self._sunspot_submodel_options[:force_association_reload]
          if self.send(self._sunspot_submodel_options[:parent]).is_a?(Enumerable)
            self.send(self._sunspot_submodel_options[:parent]).each {|item| item.solr_index }
          else
            self.send(self._sunspot_submodel_options[:parent]).solr_index 
          end
        end
      end
      
      def check_parent_solr_if_statement
        if self._sunspot_submodel_options[:if] && self._sunspot_submodel_options[:if].instance_of?(Proc)
          self._sunspot_submodel_options[:if].call(self)
        else
          true
        end
      end
      
      #to run before a save to see if this is a new record, or if fields I care about changed.
      def mark_for_parent_solr_index
        #only mark for index if the record is new, or if fields changed that I care about
        #check the if proc first
        return unless check_parent_solr_if_statement
        if self._sunspot_submodel_options[:included_attributes]
          fields_changed = !(self.changed.map {|k| k.to_sym} & self._sunspot_submodel_options[:included_attributes]).empty?
        elsif self._sunspot_submodel_options[:ignored_attributes]
          fields_changed = !(self.changed.map {|k| k.to_sym} - self._sunspot_submodel_options[:ignored_attributes]).empty?
        else
          fields_changed = true
        end
        if new_record? || fields_changed
          @marked_for_parent_solr_indexing = true
        end
      end
      
      #call reindex if I need too
      def parent_solr_index
        if @marked_for_parent_solr_indexing
          call_parent_solr_index
          remove_instance_variable(:@marked_for_parent_solr_indexing)
        end
      end
      
      #always call reindex on destroy
      def parent_solr_index_on_destroy
        call_parent_solr_index
      end

    end

    module ClassMethods
     
    end
    
  end
end
