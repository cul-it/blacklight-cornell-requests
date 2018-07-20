module BlacklightCornellRequests

  class Work

    attr_reader :bibid, :title, :author, :isbn, :pub_info, :ill_link, :scanit_link, :mann_special_delivery_link

    def initialize(bibid, solr_document)
      @bibid = bibid
      @doc = solr_document
      @title = @doc['title_display']
      @author = parse_author(@doc)
      @isbn = @doc['isbn_display']
      @pub_info = parse_pub_info(@doc)
      @ill_link = parse_ill(@doc)
      @mann_special_delivery_link = create_mann_special_delivery_link()
      @scanit_link = create_scanit_link(@doc)
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

      ill_link = ENV['ILLIAD_URL'] + '?Action=10&Form=21&url_ver=Z39.88-2004&rfr_id=info%3Asid%2Flibrary.cornell.edu'
      if @isbn
        isbns = @isbn.join(',')
        ill_link += "&rft.isbn=#{isbns}" + "&rft_id=urn%3AISBN%3A#{isbns}"
      end
      if @title
        ill_link += "&rft.title=#{CGI.escape(@title)}"
      end
      if solrdoc['author_display'].present?
        ill_link += "&rft.aulast=#{solrdoc['author_display']}"
      end

      # Populate the publisher data fields. This can be done
      # using @pub_info, which gloms everything together,
      # or by using the separate pubplace_display, publisher_display
      # and pub_date_display
      pub_date =  solrdoc['pub_date_display']  ? solrdoc['pub_date_display'][0]  : @pub_info
      publisher = solrdoc['publisher_display'] ? solrdoc['publisher_display'][0] : @pub_info
      pub_place = solrdoc['pubplace_display']  ? solrdoc['pubplace_display'][0]  : @pub_info
      ill_link += "&rft.place=#{pub_place}"
      ill_link += "&rft.pub=#{publisher}"
      ill_link += "&rft.date=#{pub_date}"

      if solrdoc['format'].present?
        ill_link += "&rft.genre=#{solrdoc['format'][0]}"
      end
      if solrdoc['lc_callnum_display'].present?
        ill_link += "&rft.identifier=#{solrdoc['lc_callnum_display'][0]}"
      end
      if solrdoc['other_id_display'].present?
        oclc = solrdoc['other_id_display'].select do |id|
          match[1] if match = id.match(/#{OCLC_TYPE_ID}([0-9]+)/)
        end

        if oclc.count > 0
          ill_link += "&rfe_dat=#{oclc.join(',')}"
        end
      end

      ill_link

    end

    def create_scanit_link(solrdoc)
      scanit_link = ENV['ILLIAD_URL'] + '?Action=10&Form=30&url_ver=Z39.88-2004&rfr_id=info%3Asid%2Fnewcatalog.library.cornell.edu'
      if @title.present?
        scanit_link << "&rft.title=#{CGI.escape(@title)}"
      end
      if @isbn.present?
        isbns = @isbn.join(',')
        scanit_link += "&rft.isbn=#{isbns}" + "&rft_id=urn%3AISBN%3A#{isbns}"
      end
      @scanit_link = scanit_link
    end

    def create_mann_special_delivery_link
      "http://mannlib.cornell.edu/use/collections/special/registration"
    end

  end

end
