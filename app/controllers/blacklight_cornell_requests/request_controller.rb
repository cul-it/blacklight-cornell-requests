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
  ## day after 17, reserve
  IRREGULAR_LOAN_TYPE = {
    :DAY => {
      '1'  => 1,
      '5'  => 1,
      '6'  => 1,
      '7'  => 1,
      '8'  => 1,
      '10' => 1,
      '11' => 1,
      '13' => 1,
      '14' => 1,
      '15' => 1,
      '17' => 1,
      '18' => 1,
      '19' => 1,
      '20' => 1,
      '21' => 1,
      '23' => 1,
      '24' => 1,
      '24' => 1,
      '25' => 1,
      '28' => 1,
      '33' => 1
      },
    :MINUTE => {
      '12' => 1,
      '16' => 1,
      '22' => 1,
      '26' => 1,
      '27' => 1,
      '29' => 1,
      '30' => 1,
      '31' => 1,
      '32' => 1,
      '34' => 1,
      '35' => 1,
      '36' => 1,
      '37' => 1
    },
    # day loan items with a loan period of 1-2 days cannot use L2L
    :NO_L2L => {
      '10' => 1,
      '17' => 1,
      '23' => 1,
      '24' => 1
    },
    :NOCIRC => {
      '9'  => 1
    }
  }
  LIBRARY_ANNEX = 'Library Annex'
  HOLD_PADDING_TIME = 3
  
  class RequestController < ApplicationController
    def request_item target=''
      target = 'default' if target.blank?
      render target
    end
    
    def _display request_options, service, doc
    end

    def l2l
      return request_item L2L
    end

    def hold
      return request_item HOLD
    end

    def recall
      return request_item RECALL
    end

    def bd
      return request_item BD
    end

    def ill
      return request_item ILL
    end

    def purchase
      return request_item PURCHASE
    end

    def pda
      return request_item PDA
    end

    def ask
      return request_item ASK_LIBRARIAN
    end
  end
end
