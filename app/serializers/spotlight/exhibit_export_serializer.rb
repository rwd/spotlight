require 'roar/decorator'
require 'roar/json'
require 'base64'
require 'tempfile'

module Spotlight
  ##
  # Serialize the Spotlight::BlacklightConfiguration
  class ConfigurationRepresenter < Roar::Decorator
    include Roar::JSON

    (Spotlight::BlacklightConfiguration.attribute_names - %w(id exhibit_id)).each do |prop|
      property prop
    end
  end

  ##
  # Serialize an exhibit with all the data needed to reconstruct it
  # in a different environment
  class ExhibitExportSerializer < Roar::Decorator
    include Roar::JSON

    (Spotlight::Exhibit.attribute_names - %w(id default slug)).each do |prop|
      property prop
    end

    collection :searches, parse_strategy: ->(fragment, _i, options) { options.represented.searches.find_or_initialize_by(slug: fragment['slug']) },
                          class: Spotlight::Search do
      (Spotlight::Search.attribute_names - %w(id exhibit_id)).each do |prop|
        property prop
      end
    end

    collection :about_pages, parse_strategy: ->(fragment, _i, options) { options.represented.about_pages.find_or_initialize_by(slug: fragment['slug']) },
                             class: Spotlight::AboutPage,
                             decorator: PageRepresenter

    collection :feature_pages, parse_strategy: ->(fragment, _i, options) { options.represented.feature_pages.find_or_initialize_by(slug: fragment['slug']) },
                               getter: ->(_opts) { feature_pages.at_top_level },
                               class: Spotlight::FeaturePage,
                               decorator: NestedPageRepresenter

    property :home_page, parse_strategy: ->(_fragment, options) { options.represented.home_page },
                         class: Spotlight::HomePage,
                         decorator: PageRepresenter

    property :blacklight_configuration, class: Spotlight::BlacklightConfiguration, decorator: ConfigurationRepresenter

    collection :custom_fields, parse_strategy: ->(fragment, _i, options) { options.represented.custom_fields.find_or_initialize_by(slug: fragment['slug']) },
                               class: Spotlight::CustomField do
      (Spotlight::CustomField.attribute_names - %w(id exhibit_id)).each do |prop|
        property prop
      end
    end

    collection :contacts, parse_strategy: ->(fragment, _i, options) { options.represented.contacts.find_or_initialize_by(slug: fragment['slug']) },
                          class: Spotlight::Contact do
      (Spotlight::Contact.attribute_names - %w(id exhibit_id avatar)).each do |prop|
        property prop
      end

      property :avatar, exec_context: :decorator

      def avatar
        file = represented.avatar.file

        { filename: file.filename, content_type: file.content_type, content: Base64.encode64(file.read) }
      end

      def avatar=(file)
        represented.avatar = CarrierWave::SanitizedFile.new tempfile: StringIO.new(Base64.decode64(file['content'])),
                                                            filename: file['filename'],
                                                            content_type: file['content_type']
      end
    end

    collection :contact_emails, class: Spotlight::ContactEmail do
      (Spotlight::ContactEmail.attribute_names - %w(id exhibit_id)).each do |prop|
        property prop
      end
    end

    collection :solr_document_sidecars, class: Spotlight::SolrDocumentSidecar do
      (Spotlight::SolrDocumentSidecar.attribute_names - %w(id document_type exhibit_id)).each do |prop|
        property prop
      end

      property :document_type, exec_context: :decorator

      def document_type
        represented.document_type.to_s
      end

      delegate :document_type=, to: :represented
    end

    collection :owned_taggings, class: ActsAsTaggableOn::Tagging do
      property :taggable_id
      property :taggable_type
      property :context
      property :tag, exec_context: :decorator

      def tag
        represented.tag.name
      end

      def tag=(tag)
        represented.tag = ActsAsTaggableOn::Tag.find_or_create_by name: tag
      end
    end

    collection :attachments, class: Spotlight::Attachment do
      (Spotlight::Attachment.attribute_names - %w(id exhibit_id file)).each do |prop|
        property prop
      end

      property :file, exec_context: :decorator

      def file
        file = represented.file.file

        { filename: file.filename, content_type: file.content_type, content: Base64.encode64(file.read) }
      end

      def file=(file)
        represented.file = CarrierWave::SanitizedFile.new tempfile: StringIO.new(Base64.decode64(file['content'])),
                                                          filename: file['filename'],
                                                          content_type: file['content_type']
      end
    end

    collection :resources, class: ->(fragment, *) { fragment.key?('type') ? fragment['type'].constantize : Spotlight::Resource } do
      (Spotlight::Resource.attribute_names - %w(id exhibit_id url)).each do |prop|
        property prop
      end

      property :file, exec_context: :decorator

      def file
        file = represented.url.file

        { filename: file.filename, content_type: file.content_type, content: Base64.encode64(file.read) }
      end

      def file=(file)
        represented.url = CarrierWave::SanitizedFile.new tempfile: StringIO.new(Base64.decode64(file['content'])),
                                                         filename: file['filename'],
                                                         content_type: file['content_type']
      end
    end
  end
end
