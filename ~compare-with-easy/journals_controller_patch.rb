module JournalsControllerPatch
  def self.included(base)
    base.class_eval do
      def authorize_with_ca(ctrl = params[:controller], action = params[:action], global = false)
        global ||= @journal.respond_to?(:journalized_type) && @journal.journalized_type.in?(%w{Acc Lead})
        authorize_without_ca(ctrl, action, global)
      end
      
      alias_method_chain :authorize, :ca
    end
  end
end

EasyExtensions::PatchManager.register_helper_patch 'JournalsController', 'JournalsControllerPatch'
