module ContextMenusControllerPatch
  def self.included(base)
    base.class_eval do
      def crm_entity(entity)
        model = entity.camelcase.constantize
        
        @issues = model.all(:conditions => {:id => params[:ids]})
        (render_404; return) unless @issues.present?
        @issue = @issues.first if @issues.size == 1
        @issue_ids = @issues.map(&:id).sort
        
        can_manage = User.current.allowed_to?(:manage_crm, nil, global: true)
        @can = {:edit => can_manage, :delete => can_manage}
        @assignables = @issues.first.assignable_users.sort_by(&:name)
        @back = back_url
  
        @options_by_custom_field = {}
        if @can[:edit]
          custom_fields = @issues.map(&:available_custom_fields).reduce(:&).select do |f|
            %w(bool list user).include?(f.field_format) && !f.multiple?
          end
          custom_fields.each do |field|
            values = field.possible_values_options(nil)
            if values.any?
              @options_by_custom_field[field] = values
            end
          end
        end
  
        @safe_attributes = @issues.map(&:safe_attribute_names).reduce(:&)
        @project = PluginName.find_project # PluginName
        render :layout => false
      end
      
      def accs
        crm_entity 'acc'
      end
      
      def leads
        crm_entity 'lead'
      end
    end
  end
end

EasyExtensions::PatchManager.register_controller_patch 'ContextMenusController', 'ContextMenusControllerPatch'
