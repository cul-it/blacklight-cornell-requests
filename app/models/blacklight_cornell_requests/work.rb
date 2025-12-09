module BlacklightCornellRequests
  class Work
    attr_reader :bibid, :title, :author, :isbn, :pub_info, :ill_link, :scanit_link

    def initialize(bibid, solr_document)
      @bibid = bibid
      @doc = solr_document
      @title = @doc['title_display']
      @author = parse_author(@doc)
      @isbn = @doc['isbn_display']
      @oclc = solr_document['oclc_id_display']
      @pub_info = parse_pub_info(@doc)
      @ill_link = parse_ill(@doc)
      @scanit_link = create_scanit_link(@doc)
    end

    def call_number(solrdoc = @doc)
      solrdoc['callnumber_display']&.first || ''
    end

    def parse_author(solrdoc)
      if solrdoc['author_display'].present?
        solrdoc['author_display'].split('|')[0]
      elsif solrdoc['author_addl_display'].present?
        solrdoc['author_addl_display'].map { |author| author.split('|')[0] }.join(', ')
      else
        ''
      end
    end

    # Populate the publisher data fields. This can be done
    # using pub_info_display, which gloms everything together,
    # or by using the separate pubplace_display, publisher_display
    # and pub_date_display
    def parse_pub_info(solrdoc)
      solrdoc['pub_info_display'].present? ? solrdoc['pub_info_display'][0] : ''
    end

    def parse_ill(solrdoc)
      ill_link = "#{ENV['ILLIAD_URL']}?Action=10&Form=21&url_ver=Z39.88-2004&rfr_id=info%3Asid%2Flibrary.cornell.edu"
      if @isbn
        isbns = @isbn.join(',')
        ill_link += "&LoanIsbn=#{isbns}" + "&rft_id=urn%3AISBN%3A#{isbns}"
      end
      ill_link += "&LoanTitle=#{CGI.escape(@title)}" if @title
      if solrdoc['author_addl_display'].present?
        ill_link += "&LoanAuthor=#{solrdoc['author_addl_display'][0]}"
      else
        ill_link += "&LoanAuthor=#{solrdoc['author_display']}"
      end

      # Populate the publisher data fields. This can be done
      # using @pub_info, which gloms everything together,
      # or by using the separate pubplace_display, publisher_display
      # and pub_date_display
      pub_date =  solrdoc['pub_date_display']  ? solrdoc['pub_date_display'][0]  : @pub_info
      publisher = solrdoc['publisher_display'] ? solrdoc['publisher_display'][0] : @pub_info
      pub_place = solrdoc['pubplace_display']  ? solrdoc['pubplace_display'][0]  : @pub_info
      ill_link += "&LoanPlace=#{pub_place}"
      ill_link += "&LoanPublisher=#{publisher}"
      ill_link += "&LoanDate=#{pub_date}"

      ill_link += "&rft.genre=#{solrdoc['format'][0]}" if solrdoc['format'].present?
      ill_link += "&rft.identifier=#{call_number()}"
      ill_link += "&ESPNumber=#{@oclc.join(', ')}" if @oclc.present?
      ill_link += "&ISSN=#{@isbn.join(', ')}" if @isbn.present?
      ill_link += "&CitedIn=Cornell University Library catalog"

      ill_link
    end

    def create_scanit_link(solrdoc)
      scanit_link = "#{ENV['ILLIAD_URL']}?Action=10&Form=30&url_ver=Z39.88-2004&rfr_id=info%3Asid%2Fcatalog.library.cornell.edu"
      scanit_link << "&rft.title=#{CGI.escape(@title)}" if @title.present?
      if @isbn.present?
        isbns = @isbn.join(',')
        scanit_link += "&rft.isbn=#{isbns}" + "&rft_id=urn%3AISBN%3A#{isbns}"
      end
      @scanit_link = scanit_link
    end
  end
end
