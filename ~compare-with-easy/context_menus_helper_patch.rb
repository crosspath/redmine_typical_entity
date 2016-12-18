module ContextMenusHelperPatch
  def self.included(base)
    base.class_eval do
      
      def bulk_update_custom_field_context_menu_link_crm(entity, field, value, text, link_options={})
        url_options = {project_id: @project.id, ids: @issue_ids, back_url: @back}
        url_options[entity.to_sym] = {field => value}
        
        context_menu_link(text,
          send("bulk_update_project_#{entity.pluralize}_path", url_options),
          {method: :post, disabled: !@can[:edit]}.merge(link_options)
        )
      end
      
      def bulk_update_custom_field_context_menu_link_acc(field, value, text, link_options={})
        bulk_update_custom_field_context_menu_link_crm('acc', field, value, text, link_options)
      end
      
      def bulk_update_custom_field_context_menu_link_lead(field, value, text, link_options={})
        bulk_update_custom_field_context_menu_link_crm('lead', field, value, text, link_options)
      end
      
    end
  end
end

EasyExtensions::PatchManager.register_helper_patch 'ContextMenusHelper', 'ContextMenusHelperPatch'
