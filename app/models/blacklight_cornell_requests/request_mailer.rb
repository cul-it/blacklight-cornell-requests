# -*- encoding : utf-8 -*-
module BlacklightCornellRequests
  class RequestMailer < ActionMailer::Base
    
    default :from => "culsearch@cornell.edu"
    default :subject => "Purchase Request"
    default :to => "***REMOVED***"
    
    def email_request(user, params)
      @params = params
      @user = user
      
      mail().deliver
      logger.debug "Sent purchase request on behalf of #{user}."
    end
  end
end
