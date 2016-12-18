module ModalSelectorsControllerPatch
  def self.included(base)
    base.class_eval do
      def crm_entity(entity)
        query_type = "#{entity}Query".camelcase.constantize
        localization = "#{entity}_query.easy_lookup.name.#{entity}.default"
        
        query = query_type.new(:name => l(localization + (params[:query_name].blank? ? ".default" : params[:query_name])))
        query.display_filter_fullscreen_button = false

        qp = params.dup
        qp.delete(:project_id)
        qp.delete(:parent_selection)

        set_query(query, qp)

        query = query_type.new(:name => query.name) unless query.valid?

        sort_init(query.sort_criteria_init)
        sort_update(query.sortable_columns)

        entity_count = query.entity_count
        entity_pages = Redmine::Pagination::Paginator.new entity_count, default_per_page_rows, params['page']

        if entity_pages.last_page.to_i < params['page'].to_i
          render_404
          return false
        end

        entities = query.entities(:order => sort_clause, :offset => entity_pages.offset, :limit => default_per_page_rows)

        render_modal_selector_list(query, entities, entity_pages, entity_count)
      end
      
      def acc; crm_entity 'acc'; end
      def lead; crm_entity 'lead'; end
      
      def domain
        respond_to do |format|
          format.html { render partial: 'domains/modal' }
        end
      end
    end
  end
end

EasyExtensions::PatchManager.register_controller_patch 'ModalSelectorsController', 'ModalSelectorsControllerPatch'
