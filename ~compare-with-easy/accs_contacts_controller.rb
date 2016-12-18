class AccsContactsController < ApplicationController
  unloadable    
  
  before_filter :find_project_by_project_id
  before_filter :find_object
  before_filter :authorize, :only => [:add, :update, :delete]
  before_filter :find_contact, :except => [:add, :list]    

  helper :contacts
  
  typical_contacts 'acc'
end
