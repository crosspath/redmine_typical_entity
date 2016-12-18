module TypicalContactsController
  extend ActiveSupport::Concern
  module ClassMethods
    # REQUIRES: 'entity'
    def typical_contacts(entity)
      cattr_accessor :tc
      self.tc = entity.to_s
      include TypicalContactsController::InstanceMethods
    end
  end
  
  module InstanceMethods
    def list
      klass = object_contact_model
      objects = klass.where(klass.reflections[self.tc.to_sym].foreign_key => @issue.id).includes(:contact)
      respond_to { |format| format.json { render json: objects } }
    end
    
    def add
      @show_form = "true"

      if params[:contact_id] && request.post? then
        find_contact
        klass = object_contact_model
        join = klass.new params[klass.name.underscore.to_sym]
        {self.tc.to_sym => @issue.id, :contact => @contact.id}.each do |refl, value|
          join.send(join.reflections[refl].foreign_key + '=', value)
        end
        join.save
      end
      
      respond_to do |format|
        format.html { redirect_to :back }
        format.js
      end
    end  

    def update
      find_contact
      klass = object_contact_model
      p = {}
      {self.tc.to_sym => @issue.id, :contact => @contact.id}.each do |refl, value|
        p[klass.reflections[refl].foreign_key] = value
      end
      join = klass.where(p).update_all(params[klass.name.underscore.to_sym])
      
      respond_to do |format|
        format.html { redirect_to :back }
        format.js { render action: 'add' }
      end
    end
    
    def delete    
      @issue.contacts.delete(@contact)
      respond_to do |format|
        format.html { redirect_to :back }
        format.js
      end
    end

    private
    
    def find_contact 
      @contact = Contact.find(params[:contact_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def find_object
      model = self.tc.classify.constantize
      @issue = model.find(params["#{self.tc}_id".to_sym])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
    
    def object_contact_model
      ents = self.tc.pluralize
      klass = "#{ents.camelcase}Contact".constantize
    end
    
    # зачем?
    def assigned_to_users
      user_values = []
      user_values << ["<< #{l(:label_all)} >>", ""]
      user_values << ["<< #{l(:label_me)} >>", User.current.id] if User.current.logged?
      
      project_ids = Project.all(:conditions => Project.visible_condition(User.current)).collect(&:id)
      if project_ids.any?
        # members of the user's projects
        user_values += User.active.find(:all, :conditions => ["#{User.table_name}.id IN (SELECT DISTINCT user_id FROM members WHERE project_id IN (?))", project_ids]).sort.collect{|s| [s.name, s.id.to_s] }
      end
    end
  end
end

ApplicationController.send(:extend, TypicalContactsController::ClassMethods)
