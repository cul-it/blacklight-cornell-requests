BlacklightCornellRequests::Engine.routes.draw do
  match 'hold/:id' => 'request#hold', :as =>'request_hold' , :constraints => { :id => /.+/}
  match 'recall/:id' => 'request#recall', :as =>'request_recall'
  match 'callslip/:netid/:id' =>'request#callslip', :as =>'request_callslip'
  match 'l2l/:id' =>'request#l2l', :as =>'request_l2l'
  match 'bd/:id' =>'request#bd', :as =>'request_bd'
  match 'ill/:id' =>'request#ill', :as =>'request_ill'
  match 'purchase/:id' =>'request#purchase', :as =>'request_purchase'
  match 'ask/:id' =>'request#ask', :as =>'request_ask'
  match 'voyager' => 'request#make_request', :as => 'request_make_request', :via => :post
  match '/:id' => 'request#request', :as => 'request'
end
