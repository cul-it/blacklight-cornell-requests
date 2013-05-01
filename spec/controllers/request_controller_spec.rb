require 'spec_helper'
require 'blacklight_cornell_requests/request_controller'

describe BlacklightCornellRequests::RequestController, :type => :controller do

	describe "GET /" do

		it "renders the :index view" do
			get :request_item, :id => 123
			response.should render_template :index
		end
	end


end
