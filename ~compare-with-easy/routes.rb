def concern_contacts
  match 'list'
  match 'add'
  match 'update'
  match 'delete'
end

def concern_entity
  collection do
    match 'bulk_edit', :via => [:get, :post]
    post 'bulk_update'
    delete '', action: :destroy
  end
  member do
    get 'render_last_journal'
    get 'toggle_description'
    put 'update_form'
  end
end

resources :projects do
  resources :accs do
    concern_entity
  end
  
  resources :domains, only: :index
  
  resources :leads do
    concern_entity
    collection do
      get 'new_from_domains'
      post 'create_from_domains'
    end
  end
end

namespace :accs_contacts do concern_contacts end
namespace :leads_contacts do concern_contacts end

match '/accs/context_menu', :to => 'context_menus#accs', :as => 'accs_context_menu', :via => [:get, :post]
match '/leads/context_menu', :to => 'context_menus#leads', :as => 'leads_context_menu', :via => [:get, :post]

resources :accs
resources :leads do
  get 'check', on: :collection
  #get 'toggle_description', on: :member
end

get '/modal_selectors/domain' => 'modal_selectors#domain'


scope '/settings' do
  resources :lead_statuses
end
