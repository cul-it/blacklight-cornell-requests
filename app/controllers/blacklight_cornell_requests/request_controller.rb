require_dependency "blacklight_cornell_requests/application_controller"

module BlacklightCornellRequests
  
  L2L = 'l2l'
  BD = 'bd'
  HOLD = 'hold'
  RECALL = 'recall'
  PURCHASE = 'purchase' # Note: this is a *purchase request*, which is different from a patron-driven acquisition
  PDA = 'pda'
  ILL = 'ill'
  ASK_CIRCULATION = 'circ'
  ASK_LIBRARIAN = 'ask'
  LIBRARY_ANNEX = 'Library Annex'
  HOLD_PADDING_TIME = 3
  
  class RequestController < ApplicationController
    def magic_request target=''
      target = 'default' if target.blank?
      render target
    end
    
    def _display request_options, service, doc
    end

    def l2l
      return request L2L
    end

    def hold
      return request HOLD
    end

    def recall
      return request RECALL
    end

    def bd
      return request BD
    end

    def ill
      return request ILL
    end

    def purchase
      return request PURCHASE
    end

    def pda
      return request PDA
    end

    def ask
      return request ASK_LIBRARIAN
    end
  end
end
