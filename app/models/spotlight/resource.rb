module Spotlight
  ##
  # Exhibit resources
  class Resource < ActiveRecord::Base
    include Spotlight::SolrDocument::AtomicUpdates
    extend ActiveModel::Callbacks
    define_model_callbacks :index

    class_attribute :providers
    class_attribute :weight

    belongs_to :exhibit
    serialize :data, Hash

    after_save :reindex

    around_index :reindex_with_lock

    after_index :update_index_time!

    def self.providers
      Spotlight::Engine.config.resource_providers
    end

    def self.class_for_resource(r)
      providers.select { |provider| provider.can_provide? r }.sort_by(&:weight).first
    end

    ##
    # @abstract
    # Convert the resource into a new solr document.
    def to_solr
      exhibit.solr_data.merge(Spotlight::Resource.resource_global_id_field => to_global_id.to_s,
                              Spotlight::SolrDocument.resource_type_field => self.class.to_s.tableize)
    end

    def self.resource_global_id_field
      :"#{Spotlight::Engine.config.solr_fields.prefix}spotlight_resource_id#{Spotlight::Engine.config.solr_fields.string_suffix}"
    end

    def reindex_with_lock
      with_lock do
        yield
      end
    end

    def reindex
      run_callbacks :index do
        data = to_solr
        data = [data] unless data.is_a? Array
        blacklight_solr.update params: { commitWithin: 500 }, data: data.to_json, headers: { 'Content-Type' => 'application/json' } unless data.empty?
      end
    end

    def update_index_time!
      update_columns indexed_at: Time.current
    end

    def becomes_provider
      klass = Spotlight::Resource.class_for_resource(self)

      if klass
        self.becomes! klass
      else
        self
      end
    end

    def needs_provider?
      type.blank?
    end

    def save_and_commit
      save.tap do
        begin
          blacklight_solr.commit
        rescue => e
          Rails.logger.warn "Unable to commit to solr: #{e}"
        end
      end
    end

    protected

    def blacklight_solr
      @solr ||= RSolr.connect(connection_config)
    end

    def connection_config
      Blacklight.connection_config
    end

    def document_model
      exhibit.blacklight_config.document_model
    end
  end
end
