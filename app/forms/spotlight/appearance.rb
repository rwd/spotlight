module Spotlight
  ##
  # Exhibit appearance form presenter
  class Appearance
    extend ActiveModel::Naming
    extend ActiveModel::Translation
    include ActiveModel::Conversion

    def initialize(configuration)
      @configuration = configuration
    end

    attr_reader :configuration
    delegate :persisted?, :exhibit, :exhibit_id, :default_per_page,
             :default_blacklight_config, to: :configuration

    delegate :main_navigations, :searchable, to: :exhibit

    def self.validators_on(*args)
      Spotlight::Exhibit.validators_on(*args)
    end

    ##
    # This enables us to have a group of checkboxes that is backed by the array
    # stored in Spotlight::BlacklightConfiguration#document_index_view_types
    def document_index_view_types
      vals = configuration.document_index_view_types
      Blacklight::OpenStructWithHashAccess.new.tap do |s|
        view_type_options.each do |k|
          s[k] = vals.include?(k.to_s)
        end
      end
    end

    def update(params)
      exhibit_status = configuration.exhibit.update(exhibit_params(params))
      configuration_status = configuration.update(configuration_params(params))
      exhibit_status && configuration_status
    end

    def view_type_options
      default_blacklight_config.view.select { |_k, v| v.if != false }.keys
    end

    def per_page_options
      default_blacklight_config.per_page
    end

    def errors
      errors = ActiveModel::Errors.new(self)
      (configuration.exhibit.errors.to_a + configuration.errors.to_a).each do |e|
        errors.add :base, e
      end
      errors
    end

    protected

    def configuration_params(params)
      p = params.except(:main_navigations, :searchable, :masthead, :thumbnail)
      p[:document_index_view_types] = keep_selected_values(p[:document_index_view_types])
      p
    end

    def exhibit_params(params)
      p = { searchable: params[:searchable] }

      main_nav_attributes = params[:main_navigations].try(:values)
      masthead_attributes = params[:masthead]
      thumbnail_attributes = params[:thumbnail]

      p[:main_navigations_attributes] = main_nav_attributes if main_nav_attributes

      p[:masthead_attributes] = masthead_attributes if masthead_attributes && masthead_changed?(masthead_attributes)

      p[:thumbnail_attributes] = thumbnail_attributes if thumbnail_attributes && thumbnail_changed?(thumbnail_attributes)

      p
    end

    ##
    # A group of checkboxes on a form returns values like this:
    #   {"list"=>["0", "1"], "gallery"=>["0", "1"], "map"=>["0"]}
    # where, "list" and "gallery" are selected and "map" is not. This function
    # digests that hash into a list of selected values. e.g.:
    #   ["list", "gallery"]
    def keep_selected_values(h)
      return if h.nil?
      h.each_with_object([]) { |(k, v), o| o << k if v.include?('1') }
    end

    private

    def masthead_changed?(masthead_attributes)
      configuration.exhibit.masthead.present? || masthead_attributes['image'].present? || masthead_attributes['remote_image_url'].present?
    end

    def thumbnail_changed?(thumbnail_attributes)
      configuration.exhibit.thumbnail.present? || thumbnail_attributes['image'].present? || thumbnail_attributes['remote_image_url'].present?
    end
  end
end
