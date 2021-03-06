module Spotlight
  module SolrDocument
    ##
    # Finder methods for SolrDocuments
    module Finder
      extend ActiveSupport::Concern

      ##
      # Class level finder methods for documents
      module ClassMethods
        def find(id)
          solr_response = index.find(id)
          solr_response.documents.first
        end

        def index
          @index ||= blacklight_config.repository_class.new(blacklight_config)
        end

        protected

        def blacklight_config
          @conf ||= Spotlight::Engine.blacklight_config
        end
      end

      def blacklight_solr
        self.class.index.connection
      end
    end
  end
end
