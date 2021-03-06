module Spotlight
  ##
  # Administrative CRUD actions for an exhibit
  class ExhibitsController < Spotlight::ApplicationController
    before_action :authenticate_user!
    include Blacklight::SearchHelper

    load_and_authorize_resource

    def new
      build_initial_exhibit_contact_emails
    end

    def process_import
      @exhibit.import(JSON.parse(import_exhibit_params.read))
      if @exhibit.save
        redirect_to spotlight.exhibit_dashboard_path(@exhibit), notice: t(:'helpers.submit.exhibit.updated', model: @exhibit.class.model_name.human.downcase)
      else
        render action: :import
      end
    end

    def create
      @exhibit.attributes = exhibit_params

      if @exhibit.save
        redirect_to spotlight.exhibit_dashboard_path(@exhibit), notice: t(:'helpers.submit.exhibit.created', model: @exhibit.class.model_name.human.downcase)
      else
        render action: :new
      end
    end

    def show
      respond_to do |format|
        format.json do
          authorize! :export, @exhibit
          send_data JSON.pretty_generate(Spotlight::ExhibitExportSerializer.new(@exhibit).as_json),
                    type: 'application/json',
                    disposition: 'attachment',
                    filename: "#{@exhibit.friendly_id}-export.json"
        end
      end
    end

    def edit
      add_breadcrumb t(:'spotlight.exhibits.breadcrumb', title: @exhibit.title), @exhibit
      add_breadcrumb t(:'spotlight.administration.sidebar.header'), exhibit_dashboard_path(@exhibit)
      add_breadcrumb t(:'spotlight.administration.sidebar.settings'), edit_exhibit_path(@exhibit)
      build_initial_exhibit_contact_emails
    end

    def update
      if @exhibit.update(exhibit_params)
        redirect_to edit_exhibit_path(@exhibit), notice: t(:'helpers.submit.exhibit.updated', model: @exhibit.class.model_name.human.downcase)
      else
        flash[:alert] = @exhibit.errors.full_messages.join('<br>'.html_safe)
        render action: :edit
      end
    end

    def destroy
      @exhibit.destroy

      redirect_to main_app.root_url, notice: t(:'helpers.submit.exhibit.destroyed', model: @exhibit.class.model_name.human.downcase)
    end

    protected

    def current_exhibit
      @exhibit if @exhibit && @exhibit.persisted?
    end

    def exhibit_params
      params.require(:exhibit).permit(
        :title,
        :subtitle,
        :description,
        :published,
        contact_emails_attributes: [:id, :email]
      )
    end

    def import_exhibit_params
      params.require(:file)
    end

    def build_initial_exhibit_contact_emails
      @exhibit.contact_emails.build unless @exhibit.contact_emails.present?
    end
  end
end
