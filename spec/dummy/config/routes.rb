Rails.application.routes.draw do
  mount BlacklightCornellRequests::Engine => "/request"
end
