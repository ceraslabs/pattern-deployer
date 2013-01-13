PatternDeployer::Application.routes.draw do
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  devise_for :users

  get "home/index"

  match "api" => "api#index", :as => :api_root

  scope "/api" do
    resources :topologies, :only => [:index, :show, :create, :destroy, :update] do
      resources :containers, :only => [:index, :show, :create, :destroy, :update] do
        resources :nodes, :only => [:index, :show, :create, :destroy, :update] do
          resources :services, :only => [:index, :show, :create, :destroy, :update]
        end
      end

      resources :nodes do
        resources :services, :only => [:index, :show, :create, :destroy, :update]
      end

      resources :templates do
        resources :services, :only => [:index, :show, :create, :destroy, :update]
      end
    end

    resources :credentials, :only => [:index, :show, :create, :destroy, :update]
    resources :uploaded_files, :only => [:index, :show, :create, :destroy, :update]
    resources :supporting_services, :only => [:index, :show, :update]

    match "*path", :controller => "api", :action => "render_404"
  end

  resources :doc, :only => [:index]
  resources :get_started, :only => [:index]

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "home#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
