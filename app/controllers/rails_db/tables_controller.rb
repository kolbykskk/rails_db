module RailsDb
  class TablesController < RailsDb::ApplicationController
    LOAD_TABLE_ACTIONS = [:show, :data, :csv, :truncate, :destroy, :edit, :update, :xlsx, :search, :new, :create]

    before_action :find_table, only: LOAD_TABLE_ACTIONS

    def index
      @tables = RailsDb::Database.accessible_tables
    end

    def show
    end

    def new
      @record = model.new
    end

    def create
      unless RailsDb.sandbox
        @record = model.new(record_attributes)
        if @record.save
          flash[:success] = 'Record has been created successfully.'
        else
          flash[:alert] = 'There was an error creating the record.'
        end
      end
      
      build_search
      respond_to do |page|
        page.html { redirect_to action: :data, table_id: params[:table_id] }
        page.js {}
      end
    end

    def data
      session[:per_page] = per_page
      build_search
      respond_to do |page|
        page.html {}
        page.js {}
      end
    end

    def csv
      send_data(@table.to_csv, type: 'text/csv; charset=utf-8; header=present', filename: "#{@table.name}.csv")
    end

    def xlsx
      if defined? Axlsx
        render xlsx: 'table', filename: "#{@table.name}.xlsx"
      else
        raise 'RailsDb could not find Axlsx, please add it to your Gemfile: "gem \'caxlsx_rails\'"'
      end
    end

    def truncate
      unless RailsDb.sandbox
        @table.truncate
      end
      render :data
    end

    def destroy
      build_search

      unless RailsDb.sandbox
        begin
          @table.delete(params[:pk_id])
          flash[:success] = 'Record has been deleted successfully.'
        rescue => e
          flash[:alert] = "There was an error deleting the record: #{e.message}"
        end
      end

      respond_to do |page|
        page.html { redirect_to action: :data, table_id: params[:table_id] }
        page.js {}
      end
    end

    def edit
      @record = @table.as_model.find(params[:pk_id])
      respond_to do |page|
        page.html { redirect_to action: :data, table_id: params[:table_id] }
        page.js {}
      end
    end

    def update
      @record = @table.as_model.find(params[:pk_id])

      unless RailsDb.sandbox
        if @record.update(record_attributes)
          flash[:success] = 'Record has been updated successfully.'
        else
          flash[:alert] = 'There was an error updating the record.'
        end
      end

      respond_to do |page|
        page.html { redirect_to action: :data, table_id: params[:table_id] }
        page.js {}
      end
    end

    private

    def build_search
      if Rails::VERSION::MAJOR >= 5
        search_params = params.dup.permit!.to_h.with_indifferent_access
      else
        search_params = params
      end
      @q       = model.ransack(search_params[:q])
      @sql     = @q.result.page(params[:page]).per(per_page).to_sql
      @records = @q.result.page(params[:page]).per(per_page)
      @q.build_condition if @q.conditions.empty?
      @q.build_sort      if @q.sorts.empty?
    end

    def model
      @model ||= @table.as_model
    end

    def record_attributes
      attrs = params[:record].permit!
      if params[:table_id] == "users"
        attrs[:stripe_account] = nil if attrs[:stripe_account].blank?
        attrs[:agreement_embed_url] = nil if attrs[:agreement_embed_url].blank?
      end
      attrs
    end

    def find_table
      @table ||= RailsDb::Table.new(params[:id] || params[:table_id])
    end

  end
end
