#require 'faker'

FactoryGirl.define do 

	factory :request, :class => "BlacklightCornellRequests::Request" do

		initialize_with { BlacklightCornellRequests::Request.new(bibid) }
		


		ignore do
			sequence(:bibid) { |n| n + 50000000 } 
		end

		
	end
	
end