class AccsController < ApplicationController
  unloadable
  helper :journals
  helper :projects
  include ProjectsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  helper :attachments
  include AttachmentsHelper
  
  helper :easy_query
  include EasyQueryHelper
  helper :entity_attribute
  include EntityAttributeHelper
  
  before_filter :find_project, only: [:index, :new, :show, :edit, :create, :update, :render_last_journal]
  before_filter :find_object, only: [:show, :edit, :update, :toggle_description, :render_last_journal]
  before_filter :find_objects, :only => [:bulk_edit, :bulk_update, :destroy]
  before_filter :build_acc, only: [:new, :create]
  
  typical_entity 'acc'
  
  protected
  
  def build_acc
    @issue = params[:id].nil? ? Acc.new : Acc.find(params[:id])
    @issue.safe_attributes = params[:acc]
    @issue.author = User.current
    @issue.assigned_to = Principal.try_find(params[:acc][:assigned_to_id]) if params[:acc]
  end
  
end